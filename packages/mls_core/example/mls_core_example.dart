import 'package:mls_core/mls_core.dart';

/// Run from the package directory: dart run example/mls_core_example.dart
void main() {
  final alice = MlsClient('Alice');
  final bob = MlsClient('Bob');
  try {
    alice.createGroup();
    final invitation = alice.addMember(bob.createKeyPackage());
    bob.joinFromWelcome(invitation.welcome);
    print(bob.decrypt(alice.encrypt('Hello Bob')));

    // Bob merges his own update; Alice must receive and merge its commit.
    alice.processMessage(bob.updateKeys());
    print('Both clients reached epoch ${alice.state.epoch}.');
    print(alice.decrypt(bob.encrypt('Hello Alice')));
  } finally {
    alice.dispose();
    bob.dispose();
  }
}
