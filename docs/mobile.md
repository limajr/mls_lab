# Run the lab on iOS Simulator and Android

The same Dart API and Rust/OpenMLS core run on macOS, iOS Simulator, and Android. The relay and all three users still live on one device. No server or Kotlin plugin is needed.

## Toolchain setup on a Mac

Install Flutter, Xcode, and Android Studio with its Android SDK first. The iOS app now uses Flutter 3.44+ with Swift Package Manager (migration verified with Flutter 3.47.8), Rust 1.99.1, Android NDK 28.2.13676358, Android API 36, and an iOS minimum deployment target of 15.0. Android's minimum API is 24 (Android 7), inherited from this Flutter SDK.

Homebrew's `rust` package contains the host compiler. Cross-compilation also needs target standard libraries, installed through rustup:

```sh
brew install rustup
"$(brew --prefix rustup)/bin/rustup" toolchain install 1.99.1 --profile minimal \
  --target aarch64-apple-ios-sim \
  --target x86_64-apple-ios \
  --target aarch64-apple-ios \
  --target aarch64-linux-android \
  --target armv7-linux-androideabi \
  --target x86_64-linux-android
```

The hook reads the compiler version from `packages/mls_core/rust/rust-toolchain`, locates rustup on PATH or via Homebrew, and asks rustup for the exact Cargo and rustc paths. This avoids accidentally using Homebrew's host-only rustc during an Xcode build. You do not need to change your shell PATH or remove Homebrew Rust.

On this Mac, Flutter is configured to use the existing Temurin JDK 21 at `/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home`. Android Studio’s bundled Java 25 failed with Gradle 8.14. The selection was made with `flutter config --jdk-dir /Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home`; it changes Flutter’s machine-wide preference, not your shell or installed Java versions.

In Android Studio → SDK Manager, install Android SDK Platform 36 and NDK (Side by side) **28.2.13676358**. The app pins the NDK so Gradle and Rust use the same compiler. If Flutter reports missing licenses, review and accept them yourself with `flutter doctor --android-licenses`.

## iOS Simulator

Xcode 27 uses **Device Hub** for simulator windows. Select the booted iPhone in its sidebar. `simctl boot` and `flutter run` can run the device in the background without opening its GUI. Older Xcode installations use `open -a Simulator` instead.

Install an iOS runtime in Xcode → Settings → Components if none is available. No Apple signing team is required for the simulator.

```sh
cd apps/mls_demo
flutter pub get
open "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"
flutter devices
flutter run -d <simulator-id>
```

List the simulators configured on your Mac and boot the desired device:

```sh
xcrun simctl list devices available
xcrun simctl boot <simulator-id>
xcrun simctl bootstatus <simulator-id> -b
flutter run -d <simulator-id>
```

An already-booted device does not need another boot command.

To produce the simulator app without launching it:

```sh
flutter build ios --simulator --debug
```

Simulator builds and iPhone device builds are different even when both use arm64. The hook maps them to `aarch64-apple-ios-sim` and `aarch64-apple-ios` respectively, and selects the matching Xcode SDK. Physical iOS signing/distribution is outside this milestone; target mapping is provided but device signing must be configured separately.

## Android phone

1. Enable Developer options and USB debugging on the phone.
2. Connect it with a data-capable USB cable, unlock it, and approve this Mac's debugging prompt.
3. Run `flutter devices`. If it shows `unauthorized`, approve the prompt on the phone; if no device appears, check the cable/USB mode.
4. Run from `apps/mls_demo`:

```sh
flutter run -d <android-device-id>
```

To build an installable debug APK without a connected phone:

```sh
flutter build apk --debug
```

Output: `apps/mls_demo/build/app/outputs/flutter-apk/app-debug.apk`. It includes ARM64, ARMv7, and x86-64 native libraries. `flutter run` builds for the connected device automatically. Debug APKs are locally signed for development; they are not Play Store release artifacts. The generated release configuration also uses the local debug key until you configure release signing.

You can install the prepared APK with:

```sh
adb -s <android-device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

`-r` updates an existing installation without clearing app data. The lab currently keeps its MLS state only in memory, regardless of install method.

## Run the complete lesson as a device test

```sh
flutter test integration_test/lab_test.dart -d <device-id> --reporter expanded
```

This launches the actual app on the chosen target, runs all five steps, asserts both remaining users reach epoch 4, checks Bob's decryption failures, and resets the lab. It exercises the target's bundled Rust library rather than a host library. You can run the same test on either the simulator or your Android phone.

Host widget tests also exercise a 320-pixel-wide phone layout and a desktop layout. The UI scrolls to the action button on small screens.

## What the native hook does

| Flutter target | Rust target | Output |
| --- | --- | --- |
| macOS arm64 | `aarch64-apple-darwin` | dylib |
| macOS x64 | `x86_64-apple-darwin` | dylib; install this additional Rust target first |
| iOS Simulator arm64 | `aarch64-apple-ios-sim` | dylib |
| iOS Simulator x64 | `x86_64-apple-ios` | dylib |
| iOS device arm64 | `aarch64-apple-ios` | dylib; signing required |
| Android arm64-v8a | `aarch64-linux-android` | .so |
| Android armeabi-v7a | `armv7-linux-androideabi` | .so |
| Android x86_64 | `x86_64-linux-android` | .so |

Apple builds pass the SDK root and deployment version to Rust. Android builds use Flutter's NDK compiler directory and select its target/API-specific clang wrapper as Cargo's linker. The ELF link settings request 16 KB segment alignment. Flutter handles bundling, framework metadata, and signing; the hook preserves the same library basename across architectures. No manual copy into `jniLibs` or Xcode source membership is necessary.

Mobile builds currently require a macOS host. The Dart/Rust package also builds natively on Linux for CI; the Flutter demo has no Linux runner. Windows and web are not implemented. First builds download dependencies and compile each architecture; later builds use Cargo's cache. Rust source edits require a rebuild/restart, not just Flutter hot reload.

## Troubleshooting

- **Can't find crate `core`:** install the requested target for the pinned Rust version. The hook explicitly resolves rustc; changing only your shell's `cargo` path is insufficient.
- **Unsupported deployment target:** the Xcode app target and generated Swift package use iOS 15.0. There is no longer a Podfile or pod deployment-target override.
- **Missing NDK compiler:** install the pinned NDK in Android Studio's SDK Manager; do not substitute a macOS clang binary.
- **Gradle/Java compatibility:** use JDK 17 or 21 with this project's Gradle/Android Gradle Plugin versions. Android Studio may bundle a newer JDK. `flutter config --jdk-dir <jdk-home>` selects a compatible JDK for Flutter builds; this is a machine-wide Flutter preference.
- **No simulator:** install a runtime in Xcode, open Device Hub, select or boot an iPhone, and recheck `flutter devices`.
- **Old build cache:** run `flutter clean`, `flutter pub get`, and rebuild. Flutter regenerates the Swift package integration as needed.

References: [Rust iOS targets](https://doc.rust-lang.org/rustc/platform-support/apple-ios.html), [Flutter native packages](https://docs.flutter.dev/platform-integration/bind-native-code), and [Dart build hooks](https://dart.dev/tools/hooks).

## Recorded validation

- iPhone 17 Pro simulator, iOS 26.5: the complete device integration test passed using the arm64 iOS Simulator Rust library.
- Android: a debug APK was built with ARM64, ARMv7, and x86-64 MLS libraries. Exported FFI symbols and ELF 16 KB segment alignment were checked; APK `zipalign -P 16` verification passed.
- Android physical device: not yet run. Physical-device validation remains pending.
- Physical iOS and Intel iOS Simulator: target mappings are implemented, but no runtime validation has been performed on those targets.


## iOS CocoaPods removal

The iOS project now uses Swift Package Manager only. Its plugin dependency,
`integration_test`, supports SwiftPM; the Rust core is still built by the Dart
native-assets hook, independently of either dependency manager.

Migration performed:

1. Ran `pod deintegrate` in `apps/mls_demo/ios`.
2. Removed `Podfile`, `Podfile.lock`, and generated Pods/symlink files.
3. Removed Pods includes from `Flutter/Debug.xcconfig` and `Flutter/Release.xcconfig`.
4. Removed the Pods project reference from `Runner.xcworkspace`, keeping the workspace itself.
5. Preserved the existing Swift package dependency and Prepare Flutter Framework scheme pre-action.

The old Podfile’s only custom logic set an iOS 15 deployment target. That target
is already configured in the app and generated Swift package, so no replacement
pod hook is needed. CocoaPods remains installed on the Mac for other projects.

Reference: [Flutter’s CocoaPods removal guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers#how-to-remove-cocoapods-integration).
