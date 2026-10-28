import 'package:flutter/foundation.dart';
import 'package:mls_core/mls_core.dart';

class LabEvent {
  final String title;
  final String detail;
  final Uint8List? wire;
  final bool blocked;
  LabEvent(this.title, this.detail, {Uint8List? wire, this.blocked = false})
    : wire = wire == null ? null : Uint8List.fromList(wire);
}

/// An ordered, in-memory delivery service. It has no client secrets and never
/// interprets message contents. Delivery also includes removed clients, so the
/// demo tests their cryptographic inability to read, rather than filtering them.
class MemoryRelay {
  void deliver(
    Uint8List wire,
    Iterable<MlsClient> recipients,
    void Function(MlsClient, String?, MlsException?) onDelivery,
  ) {
    for (final recipient in recipients) {
      try {
        onDelivery(recipient, recipient.processMessage(wire), null);
      } on MlsException catch (error) {
        onDelivery(recipient, null, error);
      }
    }
  }
}

/// UI orchestration lives in Dart; all MLS operations are real Rust calls.
class LabController extends ChangeNotifier {
  final relay = MemoryRelay();
  late Map<String, MlsClient> clients;
  final List<LabEvent> events = [];
  int step = 0;
  String? error;
  LabController() {
    _initialize();
  }
  void _initialize() {
    clients = {
      for (final name in ['Alice', 'Bob', 'Charlie']) name: MlsClient(name),
    };
    clients['Alice']!.createGroup();
    events.add(
      LabEvent(
        'Alice creates a group',
        'Epoch 0 · Alice is the only member. Bob and Charlie have independent key stores.',
      ),
    );
  }

  GroupState? state(String name) {
    if (name == 'Bob' && step < 1 || name == 'Charlie' && step < 2) return null;
    return clients[name]!.state;
  }

  void _commit(Uint8List wire, String sender, {String? exclude}) {
    final recipients = clients.entries.where(
      (entry) =>
          entry.key != sender &&
          entry.key != exclude &&
          state(entry.key) != null,
    );
    relay.deliver(wire, recipients.map((entry) => entry.value), (
      client,
      text,
      failure,
    ) {
      if (failure != null) throw failure;
    });
    events.add(
      LabEvent(
        'Commit delivered',
        'Existing members merge the accepted change.',
        wire: wire,
      ),
    );
  }

  void _add(String name) {
    final newcomer = clients[name]!;
    final keyPackage = newcomer.createKeyPackage();
    events.add(
      LabEvent(
        '$name publishes a KeyPackage',
        'Public invitation material. Private keys remain with $name.',
        wire: keyPackage,
      ),
    );
    final added = clients['Alice']!.addMember(keyPackage);
    _commit(added.commit, 'Alice', exclude: name);
    newcomer.joinFromWelcome(added.welcome);
    events.add(
      LabEvent(
        '$name joins through Welcome',
        'The Welcome bootstraps $name into epoch ${newcomer.state.epoch}.',
        wire: added.welcome,
      ),
    );
  }

  void send(String sender, String text) {
    if (text.trim().isEmpty) return;
    _guard(() => _send(sender, text));
  }

  void _send(String sender, String text) {
    final wire = clients[sender]!.encrypt(text);
    events.add(
      LabEvent(
        '$sender → encrypted relay',
        '${wire.length} bytes · epoch ${clients[sender]!.state.epoch}',
        wire: wire,
      ),
    );
    relay.deliver(
      wire,
      clients.entries
          .where((entry) => entry.key != sender && state(entry.key) != null)
          .map((entry) => entry.value),
      (client, plaintext, failure) {
        events.add(
          failure == null
              ? LabEvent(
                  '${client.identity} decrypted',
                  plaintext ?? 'Commit merged',
                )
              : LabEvent(
                  '${client.identity} cannot decrypt',
                  failure.message,
                  blocked: true,
                ),
        );
      },
    );
  }

  void next() => _guard(() {
    switch (step) {
      case 0:
        _add('Bob');
      case 1:
        _add('Charlie');
      case 2:
        _send(
          'Alice',
          'Hello Bob and Charlie. This travelled as MLS ciphertext.',
        );
        _send('Bob', 'Hi Alice! My reply is encrypted too.');
      case 3:
        final before = clients['Bob']!.state.epoch;
        final commit = clients['Bob']!.updateKeys();
        _commit(commit, 'Bob');
        events.add(
          LabEvent(
            'Bob refreshes his keys',
            'Epoch $before → ${clients['Bob']!.state.epoch}. Fresh randomness enters the group. '
                'Recovery assumes the attacker no longer controls Bob’s device. '
                'An epoch change alone is not a compromise-recovery test.',
          ),
        );
        _send('Alice', 'We can still communicate after Bob’s update.');
      case 4:
        _commit(clients['Alice']!.removeMember('Bob'), 'Alice');
        events.add(
          LabEvent(
            'Bob is removed',
            'Alice and Charlie advance. Bob retains old state but cannot read new messages.',
          ),
        );
        _send('Alice', 'Only Charlie can read this new message.');
        _send(
          'Charlie',
          'Confirmed. Bob receives these bytes too, but cannot decrypt them.',
        );
      default:
        return;
    }
    step++;
  });
  void _guard(VoidCallback action) {
    error = null;
    try {
      action();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  void reset() {
    for (final client in clients.values) {
      client.dispose();
    }
    events.clear();
    step = 0;
    error = null;
    _initialize();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final client in clients.values) {
      client.dispose();
    }
    super.dispose();
  }
}
