//! A small OpenMLS API plus a two-function C ABI for Dart.
mod client;
use base64::{engine::general_purpose::STANDARD as B64, Engine};
pub use client::{Client, GroupState, MemberAdded, Received, Result};
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    ffi::{c_char, CStr, CString},
    sync::{Mutex, OnceLock},
};
fn err(e: impl std::fmt::Debug) -> String {
    format!("{e:?}")
}
fn field<'a>(v: &'a Value, name: &str) -> Result<&'a str> {
    v[name].as_str().ok_or_else(|| format!("Missing {name}"))
}
fn wire(v: &Value) -> Result<Vec<u8>> {
    B64.decode(field(v, "bytes")?).map_err(err)
}

// JSON is only the FFI envelope. MLS wire messages remain binary TLS encodings.
fn dispatch(client: &mut Client, op: &str, v: &Value) -> Result<Value> {
    match op {
        "key_package" => Ok(json!({"bytes": B64.encode(client.create_key_package()?)})),
        "create_group" => {
            client.create_group()?;
            Ok(json!(client.state()?))
        }
        "join" => {
            client.join_from_welcome(&wire(v)?)?;
            Ok(json!(client.state()?))
        }
        "add" => {
            let added = client.add_member(&wire(v)?)?;
            Ok(json!({"commit": B64.encode(added.commit), "welcome": B64.encode(added.welcome)}))
        }
        "encrypt" => {
            Ok(json!({"bytes": B64.encode(client.encrypt(field(v, "text")?.as_bytes())?)}))
        }
        "process" => match client.process_message(&wire(v)?)? {
            Received::Application(bytes) => {
                Ok(json!({"kind":"application", "text": String::from_utf8(bytes).map_err(err)?}))
            }
            Received::Commit => Ok(json!({"kind":"commit"})),
        },
        "update" => Ok(json!({"commit": B64.encode(client.update_keys()?)})),
        "remove" => Ok(json!({"commit": B64.encode(client.remove_member(field(v, "identity")?)?)})),
        "state" => Ok(json!(client.state()?)),
        _ => Err(format!("Unknown operation: {op}")),
    }
}

// Handles keep Rust ownership on the Rust side; Dart never dereferences a client.
#[derive(Default)]
struct Runtime {
    next: u64,
    clients: HashMap<u64, Client>,
}
impl Runtime {
    fn request(&mut self, v: Value) -> Result<Value> {
        let op = field(&v, "op")?;
        if op == "new" {
            let client = Client::new(field(&v, "identity")?)?;
            self.next += 1;
            self.clients.insert(self.next, client);
            return Ok(json!({"handle": self.next}));
        }
        let handle = v["handle"].as_u64().ok_or("Missing handle")?;
        if op == "dispose" {
            self.clients.remove(&handle);
            return Ok(json!({}));
        }
        let client = self
            .clients
            .get_mut(&handle)
            .ok_or("Invalid client handle")?;
        dispatch(client, op, &v)
    }
}
static RUNTIME: OnceLock<Mutex<Runtime>> = OnceLock::new();

/// Returns an owned UTF-8 JSON response; release it exactly once with mls_free.
/// # Safety
/// `request` must point to a live, NUL-terminated UTF-8 string for this call.
#[no_mangle]
pub unsafe extern "C" fn mls_request(request: *const c_char) -> *mut c_char {
    let result = std::panic::catch_unwind(|| -> Result<Value> {
        if request.is_null() {
            return Err("Null request".into());
        }
        let text = unsafe { CStr::from_ptr(request) }.to_str().map_err(err)?;
        let value = serde_json::from_str(text).map_err(err)?;
        RUNTIME
            .get_or_init(|| Mutex::new(Runtime::default()))
            .lock()
            .map_err(err)?
            .request(value)
    });
    let response = match result {
        Ok(Ok(value)) => json!({"ok": value}),
        Ok(Err(error)) => json!({"error": error}),
        Err(_) => json!({"error": "Rust panic; reset the application"}),
    };
    CString::new(response.to_string())
        .expect("JSON escapes NUL")
        .into_raw()
}
/// # Safety
/// `response` must be null or an unfreed pointer returned by mls_request.
#[no_mangle]
pub unsafe extern "C" fn mls_free(response: *mut c_char) {
    if !response.is_null() {
        drop(unsafe { CString::from_raw(response) });
    }
}
