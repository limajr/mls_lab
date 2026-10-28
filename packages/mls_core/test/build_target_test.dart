import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';
import '../hook/build.dart' show rustTarget;

void main() {
  test('Linux host architectures map to GNU Rust targets', () {
    expect(rustTarget(OS.linux, Architecture.x64), 'x86_64-unknown-linux-gnu');
    expect(
      rustTarget(OS.linux, Architecture.arm64),
      'aarch64-unknown-linux-gnu',
    );
  });
  test('Apple arm64 distinguishes Mac, simulator, and device', () {
    expect(rustTarget(OS.macOS, Architecture.arm64), 'aarch64-apple-darwin');
    expect(
      rustTarget(OS.iOS, Architecture.arm64, sdk: IOSSdk.iPhoneSimulator),
      'aarch64-apple-ios-sim',
    );
    expect(
      rustTarget(OS.iOS, Architecture.arm64, sdk: IOSSdk.iPhoneOS),
      'aarch64-apple-ios',
    );
    expect(
      () => rustTarget(OS.iOS, Architecture.arm64),
      throwsUnsupportedError,
    );
  });
  test('Android maps Flutter ABIs to Rust triples', () {
    expect(rustTarget(OS.android, Architecture.arm64), 'aarch64-linux-android');
    expect(rustTarget(OS.android, Architecture.arm), 'armv7-linux-androideabi');
    expect(rustTarget(OS.android, Architecture.x64), 'x86_64-linux-android');
    expect(
      () => rustTarget(OS.windows, Architecture.x64),
      throwsUnsupportedError,
    );
  });
}
