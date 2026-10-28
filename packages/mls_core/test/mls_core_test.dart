import 'dart:typed_data';
import 'package:mls_core/mls_core.dart';
import 'package:test/test.dart';

void main() {
  late MlsClient alice;
  late MlsClient bob;
  late MlsClient charlie;
  setUp(() {
    alice = MlsClient('Alice');
    bob = MlsClient('Bob');
    charlie = MlsClient('Charlie');
  });
  tearDown(() {
    alice.dispose();
    bob.dispose();
    charlie.dispose();
  });
  void join() {
    alice.createGroup();
    final added = alice.addMember(bob.createKeyPackage());
    bob.joinFromWelcome(added.welcome);
  }

  test(
    'Welcome, three members, bidirectional messages, update, and removal',
    () {
      join();
      expect(alice.state.epoch, 1);
      expect(bob.state.members, ['Alice', 'Bob']);
      final added = alice.addMember(charlie.createKeyPackage());
      expect(bob.processMessage(added.commit), isNull);
      charlie.joinFromWelcome(added.welcome);
      final wire = alice.encrypt('Hello 🌱');
      expect(bob.decrypt(wire), 'Hello 🌱');
      expect(charlie.decrypt(wire), 'Hello 🌱');
      expect(alice.decrypt(bob.encrypt('Reply')), 'Reply');
      final before = bob.state.epoch;
      final update = bob.updateKeys();
      alice.processMessage(update);
      charlie.processMessage(update);
      for (final client in [alice, bob, charlie]) {
        expect(client.state.epoch, before + 1);
      }
      expect(bob.decrypt(alice.encrypt('Fresh epoch')), 'Fresh epoch');
      final removal = alice.removeMember('Bob');
      // Charlie processes removal. Bob deliberately does NOT: even stale state
      // must not decrypt new ciphertext, independent of an application flag.
      charlie.processMessage(removal);
      final secret = alice.encrypt('After removal');
      expect(charlie.decrypt(secret), 'After removal');
      expect(() => bob.decrypt(secret), throwsA(isA<MlsException>()));
      bob.processMessage(removal);
      expect(bob.state.active, isFalse);
      expect(() => bob.encrypt('Cannot send'), throwsA(isA<MlsException>()));
    },
  );
  test('tampering and replay are rejected', () {
    join();
    final wire = alice.encrypt('Authentic');
    final damaged = Uint8List.fromList(wire)..[wire.length - 1] ^= 1;
    expect(() => bob.decrypt(damaged), throwsA(isA<MlsException>()));
    // Use a fresh generation after tampering; rejection may consume ratchet state.
    final fresh = alice.encrypt('Fresh');
    expect(bob.decrypt(fresh), 'Fresh');
    expect(() => bob.decrypt(fresh), throwsA(isA<MlsException>()));
  });
  test('Welcome requires matching private key package material', () {
    alice.createGroup();
    final added = alice.addMember(bob.createKeyPackage());
    expect(
      () => charlie.joinFromWelcome(added.welcome),
      throwsA(isA<MlsException>()),
    );
    bob.joinFromWelcome(added.welcome);
    expect(bob.state.active, isTrue);
  });
  test('malformed input and use after disposal fail safely', () {
    join();
    expect(
      () => bob.decrypt(Uint8List.fromList([0, 1, 2])),
      throwsA(isA<MlsException>()),
    );
    expect(() => alice.removeMember('Nobody'), throwsA(isA<MlsException>()));
    bob.dispose();
    bob.dispose();
    expect(() => bob.createKeyPackage(), throwsStateError);
  });
}
