//! Protocol operations independent of Dart, JSON, and the demo UI.
use openmls::prelude::tls_codec::{Deserialize, Serialize};
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_rust_crypto::OpenMlsRustCrypto;
use serde::Serialize as JsonSerialize;

const SUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;
/// The teaching API preserves OpenMLS error details as diagnostic strings.
/// Production bindings should use stable, structured error codes.
pub type Result<T> = std::result::Result<T, String>;
fn err(e: impl std::fmt::Debug) -> String {
    format!("{e:?}")
}

/// Commit for existing members and Welcome for the invited member.
pub struct MemberAdded {
    pub commit: Vec<u8>,
    pub welcome: Vec<u8>,
}

/// Non-secret information suitable for the UI.
#[derive(Debug, JsonSerialize)]
pub struct GroupState {
    pub epoch: u64,
    pub active: bool,
    pub members: Vec<String>,
}

/// Distinguishes authenticated application plaintext from a merged commit.
#[derive(Debug, PartialEq)]
pub enum Received {
    Application(Vec<u8>),
    Commit,
}

/// One identity, one crypto provider, one independent in-memory key store.
/// Each client may create or join one group during its lifetime.
pub struct Client {
    provider: OpenMlsRustCrypto,
    signer: SignatureKeyPair,
    credential: CredentialWithKey,
    group: Option<MlsGroup>,
}
impl Client {
    /// BasicCredential binds a label to a signing key, but does not verify the
    /// real-world person behind that label. Identity verification is out of scope.
    pub fn new(name: &str) -> Result<Self> {
        let provider = OpenMlsRustCrypto::default();
        let signer = SignatureKeyPair::new(SUITE.signature_algorithm()).map_err(err)?;
        signer.store(provider.storage()).map_err(err)?;
        let credential = CredentialWithKey {
            credential: BasicCredential::new(name.as_bytes().to_vec()).into(),
            signature_key: signer.to_public_vec().into(),
        };
        Ok(Self {
            provider,
            signer,
            credential,
            group: None,
        })
    }
    /// Returns TLS-encoded public material; corresponding init keys stay local.
    pub fn create_key_package(&self) -> Result<Vec<u8>> {
        KeyPackage::builder()
            .build(SUITE, &self.provider, &self.signer, self.credential.clone())
            .map_err(err)?
            .key_package()
            .tls_serialize_detached()
            .map_err(err)
    }
    /// Embedding the ratchet tree lets Welcome recipients join without a server
    /// lookup for an external tree. This trades additional bytes for simplicity.
    pub fn create_group(&mut self) -> Result<()> {
        self.require_no_group()?;
        let config = MlsGroupCreateConfig::builder()
            .ciphersuite(SUITE)
            .use_ratchet_tree_extension(true)
            .build();
        self.group = Some(
            MlsGroup::new(
                &self.provider,
                &self.signer,
                &config,
                self.credential.clone(),
            )
            .map_err(err)?,
        );
        Ok(())
    }
    pub fn join_from_welcome(&mut self, bytes: &[u8]) -> Result<()> {
        self.require_no_group()?;
        let welcome = match MlsMessageIn::tls_deserialize_exact(bytes)
            .map_err(err)?
            .extract()
        {
            MlsMessageBodyIn::Welcome(w) => w,
            _ => return Err("Expected Welcome".into()),
        };
        self.group = Some(
            StagedWelcome::new_from_welcome(
                &self.provider,
                &MlsGroupJoinConfig::default(),
                welcome,
                None,
            )
            .map_err(err)?
            .into_group(&self.provider)
            .map_err(err)?,
        );
        Ok(())
    }
    /// The demo accepts local commits immediately. A networked implementation
    /// must separate staging from merging until its relay establishes ordering.
    pub fn add_member(&mut self, key_package: &[u8]) -> Result<MemberAdded> {
        let kp = KeyPackageIn::tls_deserialize_exact(key_package)
            .map_err(err)?
            .validate(self.provider.crypto(), ProtocolVersion::Mls10)
            .map_err(err)?;
        let group = self.group.as_mut().ok_or("No group")?;
        let (commit, welcome, _) = group
            .add_members(&self.provider, &self.signer, &[kp])
            .map_err(err)?;
        let added = MemberAdded {
            commit: commit.tls_serialize_detached().map_err(err)?,
            welcome: welcome.tls_serialize_detached().map_err(err)?,
        };
        group.merge_pending_commit(&self.provider).map_err(err)?;
        Ok(added)
    }
    pub fn encrypt(&mut self, plaintext: &[u8]) -> Result<Vec<u8>> {
        self.group
            .as_mut()
            .ok_or("No group")?
            .create_message(&self.provider, &self.signer, plaintext)
            .map_err(err)?
            .tls_serialize_detached()
            .map_err(err)
    }
    /// Performs OpenMLS authentication, decryption, and protocol validation.
    /// Commits are automatically accepted under this lab's trusted-member policy.
    pub fn process_message(&mut self, bytes: &[u8]) -> Result<Received> {
        let message = MlsMessageIn::tls_deserialize_exact(bytes)
            .map_err(err)?
            .try_into_protocol_message()
            .map_err(err)?;
        let group = self.group.as_mut().ok_or("No group")?;
        match group
            .process_message(&self.provider, message)
            .map_err(err)?
            .into_content()
        {
            ProcessedMessageContent::ApplicationMessage(m) => {
                Ok(Received::Application(m.into_bytes()))
            }
            ProcessedMessageContent::StagedCommitMessage(commit) => {
                group
                    .merge_staged_commit(&self.provider, *commit)
                    .map_err(err)?;
                Ok(Received::Commit)
            }
            _ => Err("Standalone proposals are outside this demo API".into()),
        }
    }
    pub fn decrypt(&mut self, bytes: &[u8]) -> Result<Vec<u8>> {
        match self.process_message(bytes)? {
            Received::Application(plaintext) => Ok(plaintext),
            Received::Commit => Err("Expected application message, received commit".into()),
        }
    }
    /// A self-update injects fresh entropy and advances the epoch after merge.
    pub fn update_keys(&mut self) -> Result<Vec<u8>> {
        let group = self.group.as_mut().ok_or("No group")?;
        let bundle = group
            .self_update(&self.provider, &self.signer, LeafNodeParameters::default())
            .map_err(err)?;
        let commit = bundle.commit().tls_serialize_detached().map_err(err)?;
        group.merge_pending_commit(&self.provider).map_err(err)?;
        Ok(commit)
    }
    /// Labels are unique in the demo. Reject ambiguity instead of removing the
    /// wrong member if a caller introduces duplicate identities.
    pub fn remove_member(&mut self, identity: &str) -> Result<Vec<u8>> {
        let group = self.group.as_mut().ok_or("No group")?;
        let matches: Vec<_> = group
            .members()
            .filter(|m| m.credential.serialized_content() == identity.as_bytes())
            .collect();
        if matches.len() != 1 {
            return Err("Expected exactly one matching member".into());
        }
        if matches[0].index == group.own_leaf_index() {
            return Err("Self-removal is outside this API".into());
        }
        let (commit, _, _) = group
            .remove_members(&self.provider, &self.signer, &[matches[0].index])
            .map_err(err)?;
        let bytes = commit.tls_serialize_detached().map_err(err)?;
        group.merge_pending_commit(&self.provider).map_err(err)?;
        Ok(bytes)
    }
    pub fn state(&self) -> Result<GroupState> {
        let group = self.group.as_ref().ok_or("No group")?;
        Ok(GroupState {
            epoch: group.epoch().as_u64(),
            active: group.is_active(),
            members: group
                .members()
                .map(|m| String::from_utf8_lossy(m.credential.serialized_content()).into_owned())
                .collect(),
        })
    }
    fn require_no_group(&self) -> Result<()> {
        if self.group.is_some() {
            Err("Client already has a group".into())
        } else {
            Ok(())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A passive attacker gets a one-time copy of Bob's stored state. This copy
    /// never shares the live provider again and never obtains fresh randomness.
    /// Deliberately keep this helper out of the public API and FFI surface.
    fn compromise(client: &Client) -> Client {
        let provider = OpenMlsRustCrypto::default();
        *provider.storage().values.write().unwrap() =
            client.provider.storage().values.read().unwrap().clone();
        let group = MlsGroup::load(
            provider.storage(),
            client.group.as_ref().unwrap().group_id(),
        )
        .unwrap()
        .unwrap();
        Client {
            provider,
            signer: client.signer.clone(),
            credential: client.credential.clone(),
            group: Some(group),
        }
    }

    #[test]
    fn passive_snapshot_loses_access_after_compromised_member_self_update() {
        let mut alice = Client::new("Alice").unwrap();
        let mut bob = Client::new("Bob").unwrap();
        alice.create_group().unwrap();
        let added = alice
            .add_member(&bob.create_key_package().unwrap())
            .unwrap();
        bob.join_from_welcome(&added.welcome).unwrap();
        let mut attacker = compromise(&bob);
        let before = alice.encrypt(b"Before recovery").unwrap();
        assert_eq!(attacker.decrypt(&before).unwrap(), b"Before recovery");
        assert_eq!(bob.decrypt(&before).unwrap(), b"Before recovery");
        let commit = bob.update_keys().unwrap();
        alice.process_message(&commit).unwrap();
        // Give the observer the commit too; withholding traffic is not recovery.
        // A stale clone has no locally staged update with Bob's fresh secrets.
        assert!(attacker.process_message(&commit).is_err());
        let after = alice.encrypt(b"After recovery").unwrap();
        assert_eq!(bob.decrypt(&after).unwrap(), b"After recovery");
        assert!(attacker.decrypt(&after).is_err());
    }
}
