# How the package gets built

## The package boundary

The demo depends on `mls_core` by a relative path in `apps/mls_demo/pubspec.yaml`. The package itself is Dart-only at the API layer: it does not import Flutter. This lets you test it with `dart test` before involving widgets. Its Rust sources live inside the package so the build hook can find them independently of the consuming app.

A Flutter FFI package is appropriate because Rust needs a native calling convention, not a platform channel. A separate Kotlin plugin becomes useful when Android platform APIs such as Keystore are introduced.

The bridge deliberately exports only two C functions, `mls_request` and `mls_free`. A handwritten binding is small enough to inspect completely. JSON envelopes avoid fragile Rust struct layout assumptions; Base64 transports binary MLS messages inside those envelopes. The additional serialization cost is acceptable for a lab. Larger APIs could use generated bindings such as flutter_rust_bridge instead.

## One build, end to end

1. `flutter pub get` resolves the app and local package.
2. `flutter run` discovers `packages/mls_core/hook/build.dart` through Dart's native assets mechanism.
3. The hook reads the requested OS and architecture. It distinguishes macOS, iOS Simulator, iOS device, Android, and native Linux target triples; unsupported targets fail explicitly.
4. Cargo compiles the Rust crate with `--release --locked` for the requested OS and architecture, using the exact Cargo and rustc paths from the pinned rustup toolchain. Its output goes in the hook's shared cache directory.
5. The hook registers `libmls_core.dylib` (Apple) or `libmls_core.so` (Android) as a bundled `CodeAsset` named `mls_core_bindings`.
6. Flutter copies and signs the native library as part of the app bundle.
7. Dart's `@Native` declarations resolve symbols through `package:mls_core/mls_core_bindings`. No hard-coded library path is needed at runtime.
8. Dart allocates a request string; Rust returns its own response string. `finally` frees each with its original allocator, even when a protocol error is returned.

The hook lists Rust source files, `Cargo.toml`, and `Cargo.lock` as dependencies, so source changes trigger a native rebuild. Cargo performs its own incremental compilation. Rust edits need a restart/rebuild; Flutter hot reload only changes Dart code. If the cache becomes stale, run `flutter clean` followed by `flutter pub get`.

## Rust independently

```sh
cargo test --manifest-path packages/mls_core/rust/Cargo.toml
```

`rlib` makes the crate usable by Rust integration tests or other Rust programs; `cdylib` exposes the C ABI to Dart. The protocol implementation has no knowledge of JSON, Dart, widgets, or the relay. The FFI adapter keeps clients behind integer handles in a mutex-protected registry. Dropping a Dart client removes its Rust handle; reset and widget disposal explicitly release clients. There is no automatic Dart finalizer, so consumers must call `dispose()`.

## Versions and reproducibility

Initially developed using Flutter 3.38.7, Dart 3.10.7, Rust 1.99.1, and OpenMLS 0.9.2. The iOS project has since migrated to Swift Package Manager with Flutter 3.47.8; use Flutter 3.44+ for that integration. Cargo and Pub lockfiles pin the resolved dependency graph. Hook dependency major versions are chosen for Dart 3.10 compatibility. The hook reads the pinned compiler version from `rust/rust-toolchain` and resolves it through rustup. Setup installs that compiler and the required target libraries; builds do not install missing targets automatically. Lockfiles and the compiler pin do not promise byte-identical builds across SDK or OS versions.

The rustup installation supplies the host and mobile target standard libraries. macOS arm64 is validated on this machine. An Intel macOS build requires an x86_64 toolchain/standard library; a universal binary is not produced automatically. The app sets `ARCHS = $(NATIVE_ARCH_ACTUAL)` in its Debug/Release xcconfigs so both development and release builds use the host architecture. Remove that setting only after installing both Rust target libraries and validating universal packaging. The minimum macOS deployment target is 12.0, matching the installed Xcode requirements.

## Mobile builds

Mobile target selection and native packaging are implemented. See [mobile setup](mobile.md) for the toolchain matrix, Android NDK linker configuration, iOS Simulator setup, and device integration tests. The app pins Android NDK 28.2.13676358 and iOS 15.0 as its minimum deployment target.

Web is not supported by this `dart:ffi` package. A web implementation needs a separate WebAssembly binding and storage design.

## Continuous integration

`.github/workflows/validate.yml` pins Flutter 3.47.8 and reads the Rust version
from the crate's toolchain file. Ubuntu runs Cargo tests/clippy and Dart tests
against a native Linux `.so`. macOS runs Flutter analysis, widget tests, and
`flutter build macos --release`. The workflow runs on main, pull requests,
version tags, and manual dispatch. Mobile runtime checks remain separate.
