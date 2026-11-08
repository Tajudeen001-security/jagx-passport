<div align="center">

<img src="jagx_passport/static/jagx-crest.svg" alt="JagX crest" width="96" />

# JagX Passport

**Prove it. Anywhere. Offline.**

Portable, verifiable identity for the JagX ecosystem — issue, hold, present and
verify **W3C Verifiable Credentials 2.0**, secured with `eddsa-jcs-2022`.

By **JagX** and **JRILICENSE** · built for future generations.

[![tests](https://img.shields.io/badge/tests-90%20passing-3ddc84)](#testing)
[![standards](https://img.shields.io/badge/W3C-VC%20Data%20Model%202.0-f5c542)](#standards-compliance)
[![cryptosuite](https://img.shields.io/badge/cryptosuite-eddsa--jcs--2022-f5c542)](#standards-compliance)
[![license](https://img.shields.io/badge/license-Apache--2.0-9a9a9a)](LICENSE)

</div>

---

## What it is

JagX Connect is *Chat, Live, Learn, Earn*. JagX Passport is the layer that makes
the **Learn** and **Earn** parts *provable*.

Today, when someone finishes a course, earns a skill badge, or gets verified as a
creator on a platform, that proof lives inside the platform's database. It cannot
leave. If the platform changes, the proof evaporates. If a verifier wants to check
it, they have to trust the platform's word.

JagX Passport changes that. It turns an achievement into a **cryptographically
signed credential that the holder owns** — a small JSON document that:

- **verifies offline.** No API call, no database, no permission needed. The
  signature is checked against the issuer's public key, which is embedded in the
  credential's own identifier.
- **cannot be forged or edited.** Change one character of the claim and the
  signature breaks.
- **can be revoked privately.** A single shared bitstring says "index 42 is
  revoked" — never *whose* credential it was.
- **is bound to the holder.** A presentation is signed by the holder's own key and
  tied to a one-time challenge, so a credential cannot be replayed or stolen.

It is a **self-hostable engine**, not a SaaS. One process, one SQLite file, no
external services, no per-verification cost. That matters: it means a Nigerian
school, a Lagos employer, or JagX Connect itself can run the whole thing on
infrastructure they already have.

### Why this, and not another badge platform

| | Platform-hosted badges | **JagX Passport** |
|---|---|---|
| Where the proof lives | The platform's database | The holder's own wallet |
| Verification | Call the platform's API | Verify the signature locally |
| Offline | ✗ | ✓ |
| Cost per verification | API quota | ₦0 |
| Revocation privacy | Platform sees every check | Bitstring — nobody learns who |
| Standards | Often proprietary | W3C VC 2.0, DID Core, Bitstring Status List |
| Data ownership | Platform | Holder |

---

## Quickstart

```bash
# 1. install
pip install -r requirements.txt

# 2. run the service + web console
python -m jagx_passport serve
#    console  →  http://localhost:8000/
#    API docs →  http://localhost:8000/docs
```

That is the whole setup. The database is created on first run.

### Or drive it from the CLI

```bash
# create an issuer (JagX Connect, anchored to its domain)
python -m jagx_passport issuer create \
  --name "JagX Connect" \
  --method web \
  --domain jagx-buddy-connect.name.ng \
  --status-list "https://jagx-buddy-connect.name.ng/status/1"

# create a holder wallet
python -m jagx_passport holder create --label "Tajudeen"

# issue a skill credential
python -m jagx_passport issue \
  --issuer did:web:jagx-buddy-connect.name.ng \
  --subject did:key:z6Mk... \
  --type JagXSkillCredential \
  skill=Python level=Advanced \
  --out skill.json

# verify it — works offline, no network
python -m jagx_passport verify skill.json --auto-status

# revoke it, then verify again (now correctly rejected)
python -m jagx_passport revoke --issuer did:web:jagx-buddy-connect.name.ng skill.json
python -m jagx_passport verify skill.json --auto-status   # exit code 1

# build a holder-bound presentation for a verifier
python -m jagx_passport present \
  --holder did:key:z6Mk... \
  --credential skill.json \
  --domain https://hiring.example \
  --out vp.json
python -m jagx_passport verify-presentation vp.json
```

---

## Credential types

The engine ships with the types the JagX ecosystem actually needs. Each one
enforces its required claims, so a malformed credential can never be minted.

| Type | What it proves | Required claims |
|---|---|---|
| `JagXSkillCredential` | A skill or competency | `skill` |
| `JagXCourseCertificate` | Completion of a course or class | `courseName` |
| `JagXMembershipCredential` | Membership + tier | `tier` |
| `JagXCreatorCredential` | Verified creator status | `handle` |
| `JagXEmploymentCredential` | An employment record | `role`, `organisation` |
| `JagXIdentityCredential` | A minimal identity claim | `verified` |

Adding a type is a few lines in `jagx_passport/credentials.py` — declare a
`CredentialType` and register it.

---

## Architecture

```
jagx_passport/
├── crypto.py        Ed25519 · multibase/base58btc · JCS (RFC 8785) · eddsa-jcs-2022
├── did.py           did:key (self-certifying) · did:web (domain-anchored) · DID documents
├── status_list.py   Bitstring Status List — gzip + base64url, MSB-first, private revocation
├── credentials.py   issue · verify · revoke · presentations (holder binding, challenge/domain)
├── store.py         SQLite persistence — issuers, holders, credentials, status lists
├── api.py           FastAPI service — 18 REST endpoints + OpenAPI schema
├── cli.py           the jagx-passport command line
└── static/          the dark-theme web console (#0a0a0a) + JagX crest
```

**The signing path, precisely.** A credential is canonicalized with JCS
(RFC 8785), hashed with SHA-256, and signed with Ed25519. The signing input is
`SHA256(canonicalize(proofConfig)) || SHA256(canonicalize(document))` — exactly
what the `eddsa-jcs-2022` cryptosuite specifies. Because JCS sorts object keys,
reformatting the JSON (whitespace, key order) does not break the signature, but
changing any *value* does.

**Why `did:key` for holders and `did:web` for issuers.** A holder's identity
should need no infrastructure — `did:key` *is* the public key, so it resolves
offline and forever. An issuer needs to rotate keys and publish a status list, so
`did:web` anchors it to a domain they already control.

**Why the status list is a bitstring.** Revocation has to be checkable without
telling the issuer who is asking about whom. A bitstring gives a verifier exactly
one bit of information — set or not set — and nothing else. It is also tiny: a
16 KiB list covers 131,072 credentials and compresses to a few hundred bytes.

---

## API

Full interactive docs at `/docs` (OpenAPI 3.1). The core surface:

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | liveness + version |
| `GET` | `/api/v1/info` | capabilities, standards, credential types |
| `POST` | `/api/v1/issuers` | create an issuer identity |
| `GET` | `/api/v1/issuers/{did}/did.json` | the issuer's DID document |
| `POST` | `/api/v1/holders` | create a holder wallet |
| `POST` | `/api/v1/credentials/issue` | issue a signed credential |
| `POST` | `/api/v1/credentials/verify` | verify a credential |
| `POST` | `/api/v1/credentials/revoke` | revoke (sets the status bit) |
| `POST` | `/api/v1/credentials/reinstate` | undo a revocation |
| `GET` | `/api/v1/status/{list_id}` | the signed status list credential |
| `POST` | `/api/v1/presentations` | build a holder-bound presentation |
| `POST` | `/api/v1/presentations/verify` | verify a presentation |
| `GET` | `/api/v1/challenge` | a fresh verifier challenge nonce |
| `GET` | `/api/v1/stats` | store statistics |

Example — issue and verify over HTTP:

```bash
curl -X POST localhost:8000/api/v1/credentials/issue \
  -H 'Content-Type: application/json' \
  -d '{
    "issuer_did": "did:web:jagx-buddy-connect.name.ng",
    "subject_did": "did:key:z6Mk...",
    "credential_type": "JagXSkillCredential",
    "claims": {"skill": "Python", "level": "Advanced"}
  }'
```

---

## Standards compliance

| Specification | Status |
|---|---|
| W3C Verifiable Credentials Data Model 2.0 | ✓ `@context`, `type`, `issuer`, `validFrom`/`validUntil`, `credentialSubject`, `credentialStatus` |
| W3C Verifiable Credential Data Integrity 1.0 | ✓ `DataIntegrityProof` |
| W3C Data Integrity EdDSA Cryptosuites — `eddsa-jcs-2022` | ✓ JCS canonicalization + Ed25519 |
| RFC 8785 — JSON Canonicalization Scheme | ✓ implemented locally, ECMAScript number formatting |
| RFC 8032 — Ed25519 | ✓ via `cryptography` |
| W3C Bitstring Status List 1.0 | ✓ gzip + base64url, MSB-first, 16 KiB minimum |
| W3C DID Core — `did:key` | ✓ multibase + multicodec Ed25519 |
| W3C DID Core — `did:web` | ✓ `.well-known/did.json` mapping |

The canonicalizer and the multibase codec are implemented in-repo rather than
pulled from a library, so the signing path is auditable end to end.

---

## Testing

```bash
pip install pytest
python -m pytest tests/ -q
```

**90 tests, all passing.** They cover:

- `test_crypto.py` — base58 vectors, multibase, JCS ordering and number
  formatting, proof round-trips, tamper detection, wrong-key rejection
- `test_did.py` — `did:key`/`did:web` construction, resolution, verification methods
- `test_status_list.py` — MSB-first bit ordering, encode/decode, allocate/revoke,
  privacy (the published list leaks no holder data)
- `test_credentials.py` — issuance rules, expiry, revocation, reinstatement,
  issuer trust, holder binding, replay rejection
- `test_api.py` — the full HTTP lifecycle, including issue → verify → revoke →
  re-verify → reinstate, and presentation replay rejection

---

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `JAGX_PASSPORT_DB` | `jagx_passport.db` | path to the SQLite store |
| `JAGX_PASSPORT_CORS` | `*` | comma-separated allowed origins |

The store holds private keys. **Back it up, and never commit it** — `.gitignore`
already excludes `*.db`.

---

## Deploying

```bash
# Docker
docker build -t jagx-passport .
docker run -p 8000:8000 -v jagx-data:/data jagx-passport

# or behind any reverse proxy
python -m jagx_passport serve --host 0.0.0.0 --port 8000
```

To make an issuer's credentials verifiable by the wider world, publish two things
at the issuer's domain:

1. `https://<domain>/.well-known/did.json` — the DID document
   (`GET /api/v1/issuers/{did}/did.json`)
2. the status list credential at its `statusListCredential` URL
   (`GET /api/v1/status/{list_id}`)

---

## Roadmap

- [ ] Selective disclosure (BBS signatures) — prove `level=Advanced` without revealing the rest
- [ ] SD-JWT VC serialization for wallet interop
- [ ] A mobile wallet that holds credentials on-device
- [ ] Open Badges 3.0 export, so JagX certificates are portable to the global learning ecosystem
- [ ] QR-code presentation flow for in-person verification

---

## License

Apache-2.0 — see [LICENSE](LICENSE).

Built by **JagX** and **JRILICENSE**.
JagX Connect — *Chat, Live, Learn, Earn*.
