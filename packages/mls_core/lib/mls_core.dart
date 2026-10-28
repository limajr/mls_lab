/// Educational MLS API. Each client owns an independent Rust crypto provider.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'src/bindings.dart';
export 'src/bindings.dart' show MlsException;

/// An accepted membership change: existing members get [commit], the new member
/// gets [welcome]. These are MLS wire messages, not JSON or plaintext.
class MemberAdded {
  final Uint8List commit;
  final Uint8List welcome;
  const MemberAdded(this.commit, this.welcome);
}

class GroupState {
  final int epoch;
  final bool active;
  final List<String> members;
  GroupState._(Map<String, dynamic> value)
    : epoch = value['epoch'] as int,
      active = value['active'] as bool,
      members = List<String>.unmodifiable(value['members'] as List);
}

/// Owns one in-memory identity and at most one group. Call [dispose] when done.
///
/// Calls are synchronous for this tiny demo. A production app should serialize
/// them on a worker isolate and use persistent, encrypted storage.
class MlsClient {
  final String identity;
  final int _handle;
  bool _disposed = false;
  MlsClient(this.identity)
    : _handle = invoke({'op': 'new', 'identity': identity})['handle'] as int;

  Map<String, dynamic> _call(
    String operation, [
    Map<String, dynamic> arguments = const {},
  ]) {
    if (_disposed) throw StateError('Client has been disposed');
    return invoke({'op': operation, 'handle': _handle, ...arguments});
  }

  /// Publishes public invitation material; private init keys stay in Rust.
  Uint8List createKeyPackage() =>
      base64Decode(_call('key_package')['bytes'] as String);
  void createGroup() => _call('create_group');
  MemberAdded addMember(Uint8List keyPackage) {
    final result = _call('add', {'bytes': base64Encode(keyPackage)});
    return MemberAdded(
      base64Decode(result['commit'] as String),
      base64Decode(result['welcome'] as String),
    );
  }

  void joinFromWelcome(Uint8List welcome) =>
      _call('join', {'bytes': base64Encode(welcome)});
  Uint8List encrypt(String text) =>
      base64Decode(_call('encrypt', {'text': text})['bytes'] as String);

  /// Authenticates and decrypts an application message, or merges a commit.
  /// Returns null for a commit, plaintext for an application message.
  String? processMessage(Uint8List message) =>
      _call('process', {'bytes': base64Encode(message)})['text'] as String?;
  String decrypt(Uint8List message) =>
      processMessage(message) ??
      (throw const MlsException(
        'Expected application message, received commit',
      ));
  Uint8List updateKeys() => base64Decode(_call('update')['commit'] as String);
  Uint8List removeMember(String identity) =>
      base64Decode(_call('remove', {'identity': identity})['commit'] as String);
  GroupState get state => GroupState._(_call('state'));

  void dispose() {
    if (_disposed) return;
    _call('dispose');
    _disposed = true;
  }
}
