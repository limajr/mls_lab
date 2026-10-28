# Optional second milestone: Android Keystore

Mobile Rust builds are now implemented; validate on the intended Android device before adding storage. The current milestone deliberately loses all MLS state at shutdown.

A useful second package would be a Kotlin Flutter plugin responsible for a non-exportable Android Keystore key and authenticated encryption/decryption of persisted MLS state. The Rust package should retain ownership of MLS protocol operations. Design a narrow storage interface rather than putting platform calls into protocol methods.

The key design question is the boundary: use the Keystore key to protect serialized application storage, while OpenMLS continues to use its supported protocol algorithms and provider interfaces. Do not assume every MLS private key can be moved into hardware or that the default OpenMLS provider can transparently use a Keystore signing key.

Before implementing, define the serialized state format, versioning, atomic commit/storage transaction, backup/restore policy, rollback handling, and behavior when a key is invalidated or a device is reset. A Keystore key alone does not solve any of these problems.

Suggested acceptance tests: restart and resume a conversation; crash between commit processing and storage; reject corrupted storage; surface missing/invalidated keys; distinguish expected data loss from protocol failure. Keep logs free of exported secrets and plaintext in this milestone.

No Kotlin plugin or persistence implementation is included yet.
