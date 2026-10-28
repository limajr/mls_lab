import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// Flutter invokes this once per target architecture. Rust is cross-compiled
/// for the target, not the machine running this script. Flutter bundles/signs the
/// resulting dylib (Apple framework) or .so (Android JNI library).
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final config = input.config.code;
    final linuxHostBuild = Platform.isLinux && config.targetOS == OS.linux;
    final appleHostBuild =
        Platform.isMacOS &&
        [OS.macOS, OS.iOS, OS.android].contains(config.targetOS);
    if (!linuxHostBuild && !appleHostBuild) {
      throw UnsupportedError(
        'Supported builds: Linux on Linux; '
        'macOS, iOS, and Android from macOS.',
      );
    }
    final target = rustTarget(
      config.targetOS,
      config.targetArchitecture,
      sdk: config.targetOS == OS.iOS ? config.iOS.targetSdk : null,
    );
    final crate = input.packageRoot.resolve('rust/');
    final toolchainFile = File.fromUri(crate.resolve('rust-toolchain'));
    final toolchain = toolchainFile.readAsStringSync().trim();
    final rustup = await findRustup();
    // Xcode may prepend Homebrew to PATH. Resolve the actual pinned compiler
    // rather than letting Cargo accidentally pick the host-only rustc there.
    final rustc = (await run(rustup, [
      'which',
      '--toolchain',
      toolchain,
      'rustc',
    ])).trim();
    final cargo = (await run(rustup, [
      'which',
      '--toolchain',
      toolchain,
      'cargo',
    ])).trim();
    final environment = <String, String>{'RUSTC': rustc};
    final targetKey = target.replaceAll('-', '_').toUpperCase();

    if (config.targetOS == OS.iOS || config.targetOS == OS.macOS) {
      final sdk = config.targetOS == OS.iOS
          ? config.iOS.targetSdk.type
          : 'macosx';
      environment['SDKROOT'] = (await run('xcrun', [
        '--sdk',
        sdk,
        '--show-sdk-path',
      ])).trim();
      if (config.targetOS == OS.iOS) {
        environment['IPHONEOS_DEPLOYMENT_TARGET'] =
            '${config.iOS.targetVersion}.0';
      } else {
        environment['MACOSX_DEPLOYMENT_TARGET'] =
            '${config.macOS.targetVersion}.0';
      }
    } else if (config.targetOS == OS.android) {
      // Flutter supplies the NDK selected by android/app/build.gradle.kts.
      // Its clang wrappers add both --target and the minimum Android API level.
      final compiler = config.cCompiler;
      if (compiler == null) {
        throw StateError(
          'Flutter did not provide an Android NDK compiler. '
          'Install the NDK version declared in android/app/build.gradle.kts.',
        );
      }
      final bin = compiler.compiler.resolve('.');
      final clangTriple = target == 'armv7-linux-androideabi'
          ? 'armv7a-linux-androideabi'
          : target;
      final linker = bin.resolve(
        '$clangTriple${config.android.targetNdkApi}-clang',
      );
      if (!File.fromUri(linker).existsSync()) {
        throw StateError('NDK linker not found: ${linker.toFilePath()}');
      }
      environment['CARGO_TARGET_${targetKey}_LINKER'] = linker.toFilePath();
      environment['CC_${target.replaceAll('-', '_')}'] = linker.toFilePath();
      environment['AR_${target.replaceAll('-', '_')}'] = compiler.archiver
          .toFilePath();
      // Keep native ELF LOAD segments compatible with 16 KB Android pages.
      environment['CARGO_TARGET_${targetKey}_RUSTFLAGS'] =
          '-C link-arg=-Wl,-z,max-page-size=16384';
    }

    final buildDir = input.outputDirectoryShared.resolve('cargo/');
    await run(cargo, [
      'build',
      '--release',
      '--locked',
      '--target',
      target,
      '--manifest-path',
      crate.resolve('Cargo.toml').toFilePath(),
      '--target-dir',
      buildDir.toFilePath(),
    ], environment: environment);
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'mls_core_bindings',
        linkMode: DynamicLoadingBundled(),
        // Use the same basename for every architecture; Flutter combines Apple
        // slices itself. A simulator dylib is never interchangeable with a device dylib.
        file: buildDir.resolve(
          '$target/release/libmls_core.${[OS.android, OS.linux].contains(config.targetOS) ? 'so' : 'dylib'}',
        ),
      ),
    );
    output.dependencies.addAll([
      crate.resolve('Cargo.toml'),
      crate.resolve('Cargo.lock'),
      toolchainFile.uri,
      ...Directory.fromUri(
        crate.resolve('src/'),
      ).listSync(recursive: true).whereType<File>().map((file) => file.uri),
    ]);
  });
}

/// Explicit target selection prevents accidentally shipping a host binary.
String rustTarget(OS os, Architecture architecture, {IOSSdk? sdk}) =>
    switch ((os, architecture)) {
      (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
      (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
      (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
      (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
      (OS.iOS, Architecture.arm64) when sdk == IOSSdk.iPhoneSimulator =>
        'aarch64-apple-ios-sim',
      (OS.iOS, Architecture.x64) when sdk == IOSSdk.iPhoneSimulator =>
        'x86_64-apple-ios',
      (OS.iOS, Architecture.arm64) when sdk == IOSSdk.iPhoneOS =>
        'aarch64-apple-ios',
      (OS.android, Architecture.arm64) => 'aarch64-linux-android',
      (OS.android, Architecture.arm) => 'armv7-linux-androideabi',
      (OS.android, Architecture.x64) => 'x86_64-linux-android',
      _ => throw UnsupportedError(
        'Unsupported Rust target: $os/$architecture/$sdk',
      ),
    };

/// Homebrew rustup is keg-only when Homebrew Rust is also installed. Resolve it
/// explicitly so the user does not need to change PATH or their global compiler.
Future<String> findRustup() async {
  final onPath = await Process.run('which', ['rustup']);
  if (onPath.exitCode == 0) return (onPath.stdout as String).trim();
  try {
    final prefix = await Process.run('brew', ['--prefix', 'rustup']);
    final candidate = '${(prefix.stdout as String).trim()}/bin/rustup';
    if (prefix.exitCode == 0 && File(candidate).existsSync()) return candidate;
  } on ProcessException {
    // Report a single actionable setup error below.
  }
  throw StateError(
    'rustup is required (brew install rustup on macOS). Follow '
    'docs/mobile.md to install the pinned compiler and target libraries.',
  );
}

Future<String> run(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    environment: environment,
  );
  if (result.exitCode != 0) {
    throw StateError(
      '$executable ${arguments.join(' ')} failed.\n'
      '${result.stdout}\n${result.stderr}\nSee docs/mobile.md for setup.',
    );
  }
  return result.stdout as String;
}
