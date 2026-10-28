# MLS Learning Lab

A Flutter app and a reusable Dart FFI package backed by a small Rust/OpenMLS crate. Three users run on one device, with independent key stores and an in-memory relay. No server, account, network messaging, or keystore is required.

**Targets: macOS, iOS Simulator, and Android, built from a Mac.** See [mobile setup and run instructions](docs/mobile.md). The optional Kotlin Keystore plugin remains a separate follow-up.

## Run

Prerequisites: Flutter 3.44+ (for the iOS Swift Package Manager integration), Xcode command-line tools, and the pinned Rust toolchain managed by rustup. See [toolchain setup](docs/mobile.md#toolchain-setup-on-a-mac).

```sh
cd apps/mls_demo
flutter pub get
flutter run -d macos
```

The first launch compiles Rust automatically. There is no manual dylib copy and no separate bridge code generator. The native build hook uses Cargo and Flutter bundles its output. A release build is available with `flutter build macos`. For iOS Simulator or a USB-connected Android phone, use `flutter devices` and `flutter run -d <device-id>`.

## Explore the experiment

1. **Invite Bob:** Bob publishes a KeyPackage; Alice adds him; Bob joins using the actual MLS Welcome message. Epoch 0 → 1.
2. **Invite Charlie:** Bob receives the commit and Charlie receives his Welcome. Epoch 1 → 2.
3. **Exchange messages:** Alice and Bob send authenticated, encrypted MLS application messages. Expand journal entries to inspect the wire bytes as Base64.
4. **Update Bob’s keys:** Bob creates a self-update commit containing fresh key material. All current members reach epoch 3 and continue communicating.
5. **Remove Bob:** Alice and Charlie advance to epoch 4. The relay still delivers new ciphertext to Bob, and OpenMLS rejects his attempt to decrypt it.

The composer allows custom messages after both invitations. Reset disposes the Rust clients and starts a fresh group.

An epoch counter is not, on its own, proof of post-compromise recovery. The UI illustrates the update mechanism. A separate Rust test takes a one-time copy of Bob’s private state, proves it can decrypt before Bob’s update, supplies the update to that stale copy, and confirms it cannot decrypt afterward. This models a passive snapshot compromise after the attacker loses device access; it does not model ongoing malware or active impersonation with stolen signing credentials. See [protocol notes](docs/protocol.md).

## Read the code in this order

| Layer | Start here | What to learn |
| --- | --- | --- |
| Dart package | `packages/mls_core/lib/mls_core.dart` | A small, typed public API and explicit client lifetime |
| Native binding | `packages/mls_core/lib/src/bindings.dart` | `@Native`, UTF-8 allocation, JSON envelopes, allocator ownership |
| Build hook | `packages/mls_core/hook/build.dart` | Cargo invocation, target selection, library bundling, cache invalidation |
| Rust protocol | `packages/mls_core/rust/src/client.rs` | Credentials, KeyPackages, Welcome, commits, epoch changes |
| Rust C ABI | `packages/mls_core/rust/src/lib.rs` | Opaque numeric handles, dispatch, error translation, panic containment |
| Relay and lesson | `apps/mls_demo/lib/lab_controller.dart` | Ordered delivery without holding cryptographic secrets |
| Flutter UI | `apps/mls_demo/lib/main.dart` | User cards, guided steps, wire inspection, message composer |

See [the build walkthrough](docs/building.md) for the package lifecycle, [protocol notes](docs/protocol.md) for security assumptions, and [the Keystore follow-up](docs/keystore-next.md).

## Validate

From the repository root:

```sh
cargo test --locked --manifest-path packages/mls_core/rust/Cargo.toml
cargo clippy --locked --manifest-path packages/mls_core/rust/Cargo.toml --all-targets -- -D warnings
cd packages/mls_core
dart analyze
dart test
cd ../../apps/mls_demo
flutter analyze
flutter test
flutter build macos
```

The tests exercise real OpenMLS operations. Dart tests cross the C ABI; the Flutter widget tests run all five steps at desktop and phone widths. The device integration test repeats the lesson using the actual target native library. Coverage includes joining with the wrong private material, tampering, replay, malformed input, disposal, key updates, and removal both with and without a removal notification.

## Deliberate limits

This is a learning project, not a production messenger. Identities are unverified BasicCredential labels; one client supports one group; the relay assumes ordered, reliable delivery and no conflicting commits. State disappears on restart. The UI records plaintext for teaching, and synchronous FFI calls run on its isolate. There is no durable storage, authenticated directory, crash recovery, secure erasure guarantee, transport, membership authorization policy, or protection between simulated users in the same OS process.

Dependency lockfiles are included. The package is experimental and marked `publish_to: none` while release preparation is in progress.

## Primary references

- [OpenMLS book](https://book.openmls.tech/)
- [MLS protocol, RFC 9420](https://www.rfc-editor.org/rfc/rfc9420.html)
- [Flutter native FFI packages](https://docs.flutter.dev/platform-integration/bind-native-code)
- [Dart build hooks](https://dart.dev/tools/hooks)

## License and contributions

MIT © 2026 [Lima Junior](https://github.com/limajr). See [LICENSE](LICENSE),
[third-party components](THIRD_PARTY.md), [contributing](CONTRIBUTING.md),
and [security scope](SECURITY.md).

The project integrates OpenMLS; it does not implement a new cryptographic protocol
or claim stronger security than other OpenMLS bindings.
