# Changelog

## 0.1.0 — 2026-10-28

First tagged source release of the educational lab. Not a pub.dev release.

- Flutter demo with three simulated users and an in-memory MLS relay.
- Rust/OpenMLS package: Welcome joining, encrypted exchange, key updates, and removal.
- macOS app, iOS Simulator integration, and Android APK builds.
- Native Linux package support for automated protocol tests.
- GitHub Actions validation on Linux and macOS.
- Reproducible phone screenshots and protocol/build documentation.

The API is experimental. State remains in memory, identities are unverified
labels, and the relay assumes ordered delivery. Android physical-device testing
and independent security review remain pending.
