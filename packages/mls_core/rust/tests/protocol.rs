use mls_core::{Client, Received};

#[test]
fn welcome_update_and_removal_without_flutter() {
    let mut alice = Client::new("Alice").unwrap();
    let mut bob = Client::new("Bob").unwrap();
    let mut charlie = Client::new("Charlie").unwrap();
    alice.create_group().unwrap();
    let added = alice
        .add_member(&bob.create_key_package().unwrap())
        .unwrap();
    bob.join_from_welcome(&added.welcome).unwrap();
    let added = alice
        .add_member(&charlie.create_key_package().unwrap())
        .unwrap();
    bob.process_message(&added.commit).unwrap();
    charlie.join_from_welcome(&added.welcome).unwrap();
    let wire = bob.encrypt(b"Hello from Rust").unwrap();
    assert_eq!(alice.decrypt(&wire).unwrap(), b"Hello from Rust");
    assert_eq!(charlie.decrypt(&wire).unwrap(), b"Hello from Rust");
    let commit = bob.update_keys().unwrap();
    assert_eq!(alice.process_message(&commit).unwrap(), Received::Commit);
    charlie.process_message(&commit).unwrap();
    assert_eq!(alice.state().unwrap().epoch, 3);
    let removal = alice.remove_member("Bob").unwrap();
    charlie.process_message(&removal).unwrap();
    let wire = charlie.encrypt(b"New epoch secret").unwrap();
    assert!(bob.decrypt(&wire).is_err()); // No removal notification required.
    assert_eq!(alice.decrypt(&wire).unwrap(), b"New epoch secret");
    bob.process_message(&removal).unwrap();
    assert!(!bob.state().unwrap().active);
}

#[test]
fn ffi_owns_its_response_and_reports_malformed_json() {
    use std::ffi::{CStr, CString};
    let input = CString::new("not JSON").unwrap();
    unsafe {
        let response = mls_core::mls_request(input.as_ptr());
        let value: serde_json::Value =
            serde_json::from_str(CStr::from_ptr(response).to_str().unwrap()).unwrap();
        assert!(value["error"].is_string());
        mls_core::mls_free(response);
        let response = mls_core::mls_request(std::ptr::null());
        assert!(CStr::from_ptr(response)
            .to_str()
            .unwrap()
            .contains("Null request"));
        mls_core::mls_free(response);
        mls_core::mls_free(std::ptr::null_mut());
    }
}
