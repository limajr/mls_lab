# mls_core

An educational Dart FFI package wrapping OpenMLS in Rust. Supports macOS, iOS Simulator, and Android builds from a Mac.

```dart
import 'package:mls_core/mls_core.dart';

void main() {
  final alice = MlsClient('Alice');
  final bob = MlsClient('Bob');
  try {
    alice.createGroup();
    final invitation = alice.addMember(bob.createKeyPackage());
    bob.joinFromWelcome(invitation.welcome);
    print(bob.decrypt(alice.encrypt('Hello Bob')));
    alice.processMessage(bob.updateKeys());
    print(alice.state.epoch); // 2
  } finally {
    alice.dispose();
    bob.dispose();
  }
}
```

All operations are synchronous. Keep each client's operations ordered; always call `dispose()`. The Rust build runs automatically through `hook/build.dart` when running or testing the package. Install the pinned Rust compiler and target libraries through rustup; see `docs/mobile.md` at the repository root.

Each client supports one in-memory group. Incoming commits are automatically merged under the lab's trusted-member policy. Local commits are merged immediately, assuming a reliable ordered relay. BasicCredential labels are not verified identities. This API is for learning, not production messaging.

See the root README and `docs/` for a full build walkthrough, protocol assumptions, and mobile setup and the Keystore follow-up plan. Run `dart test` here to exercise real encryption across the FFI boundary.

Run the standalone example on macOS:

```sh
dart run example/mls_core_example.dart
```

MIT © 2026 [Jose de Assis Lima Junior](https://github.com/limajr). See [LICENSE](LICENSE).
This package is not yet published; `publish_to: none` is intentional.
