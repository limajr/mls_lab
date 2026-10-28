# MLS demo

Run `flutter pub get`, then `flutter devices` and `flutter run -d <device-id>` from this directory. Targets include macOS, iOS Simulator, and Android phones. The local `mls_core` package builds and bundles the correct Rust library automatically.

The guided five-step experiment demonstrates Welcome joining, encrypted exchange, Bob's self-update, and removal. See [mobile setup](../../docs/mobile.md) for toolchains, simulator startup, USB debugging, APK builds, and device integration tests.

Use `flutter test integration_test/lab_test.dart -d <device-id>` to run the full lesson with real native cryptography on a simulator or phone.
