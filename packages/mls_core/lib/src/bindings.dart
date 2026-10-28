import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// This asset ID matches the CodeAsset registered in hook/build.dart.
@Native<Pointer<Utf8> Function(Pointer<Utf8>)>(
  symbol: 'mls_request',
  assetId: 'package:mls_core/mls_core_bindings',
)
external Pointer<Utf8> _request(Pointer<Utf8> request);

@Native<Void Function(Pointer<Utf8>)>(
  symbol: 'mls_free',
  assetId: 'package:mls_core/mls_core_bindings',
)
external void _free(Pointer<Utf8> response);

/// A protocol or API error returned by Rust, without crossing the FFI boundary.
class MlsException implements Exception {
  final String message;
  const MlsException(this.message);
  @override
  String toString() => 'MlsException: $message';
}

Map<String, dynamic> invoke(Map<String, dynamic> command) {
  final input = jsonEncode(command).toNativeUtf8();
  Pointer<Utf8> output = nullptr;
  try {
    output = _request(input);
    if (output == nullptr) throw const MlsException('Null native response');
    final response = jsonDecode(output.toDartString()) as Map<String, dynamic>;
    if (response case {'error': final String message}) {
      throw MlsException(message);
    }
    return response['ok'] as Map<String, dynamic>;
  } finally {
    // Dart allocated input; Rust allocated output. Each allocator frees its own.
    malloc.free(input);
    if (output != nullptr) _free(output);
  }
}
