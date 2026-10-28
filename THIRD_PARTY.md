# Third-party components

The MIT license in this repository applies to this project's original code.
Dependencies retain their own licenses and notices.

- [OpenMLS](https://github.com/openmls/openmls) implements the MLS protocol.
- `openmls_rust_crypto` supplies the cryptographic provider.
- `openmls_basic_credential` supplies basic signing credentials.
- Flutter, Dart, and the dependencies recorded in the Pub and Cargo lockfiles
  supply the application framework and build/runtime support.

Dependency sources are resolved by Pub and Cargo, not vendored here. This file
is an attribution overview, not a complete third-party notice bundle. Before
publishing compiled native libraries or app releases, generate and review the
full notices for the exact dependency graph and target architectures, and ship
them with those artifacts. Keep the Cargo and Pub lockfiles with source releases.
