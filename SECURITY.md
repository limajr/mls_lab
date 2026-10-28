# Security scope

This is an educational MLS integration, not an audited messaging SDK. OpenMLS
provides the protocol implementation; this wrapper, relay policy, and storage
choices have not received an independent security review.

Known limits are described in [protocol notes](docs/protocol.md): state is
in memory, identities are unverified labels, commits are automatically accepted,
and all simulated clients share one process. Do not put real confidential
conversations into the lab.

For a suspected vulnerability, contact the maintainer through a private contact
method listed on [limajr's GitHub profile](https://github.com/limajr). If none is
listed, open an issue requesting a private reporting channel without including
exploit details, secrets, or personal data. There is no promised response time.

Reports should identify the affected revision, platform, and expected versus
observed behavior. Use synthetic messages and identities for reproductions.
