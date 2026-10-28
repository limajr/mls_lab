# Contributing

The lab focuses on explaining the Flutter–Rust boundary and MLS group operations.
Keep changes small enough to review and preserve the separation between the Rust
protocol implementation, Dart bindings, relay, and UI.

Read [the build walkthrough](docs/building.md) and [protocol assumptions](docs/protocol.md)
first. Follow [mobile setup](docs/mobile.md) to install the pinned Rust targets.

From the repository root, run the checks relevant to your change:

```sh
cargo fmt --manifest-path packages/mls_core/rust/Cargo.toml --check
cargo test --locked --manifest-path packages/mls_core/rust/Cargo.toml
cd packages/mls_core
dart analyze
dart test
cd ../../apps/mls_demo
flutter analyze
flutter test
```

For native packaging changes, also build the affected platform and run
`flutter test integration_test/lab_test.dart -d <device-id>` on that target.
Report the SDK, OS, target architecture, and commands actually tested. Building
an APK alone does not establish that it runs on a physical device.

Explain the problem, the chosen behavior, and any remaining limitations in a
pull request. Keep credentials, signing files, generated caches, and binaries
out of source commits. Changes to the public API should include an example and
an entry under Unreleased in the package changelog.
