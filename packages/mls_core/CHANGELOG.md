# Changelog

## 0.1.0 — 2026-10-28

Included in the v0.1.0 GitHub source release; not published to pub.dev.

- Wrap OpenMLS key packages, group creation, Welcome joining, messages, key updates, and removal.
- Expose a small synchronous Dart API backed by an independent Rust client per identity.
- Build native assets for macOS, iOS, and Android from a macOS host.
- Build and test the Dart/Rust package natively on Linux.
- Test invitation handling, message authentication, replay rejection, and removal.

State is in memory. The API assumes a reliable ordered relay and trusted local members.
