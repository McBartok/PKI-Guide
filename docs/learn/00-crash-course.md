---
title: 0. Crash course
parent: Learn path
nav_order: 0
---

# 0. Crash Course: The Whole Picture in One Sitting

**Goal:** get a working mental model of everything in this guide, shallowly. Chapters 1-6 revisit each piece in depth. If you already know this material, skip to [chapter 1](01-crypto-foundations.md).

## 1. Why cryptography? The CIA triad

Security goals are usually summarised as:

| Goal | Question it answers | Does crypto provide it? |
|---|---|---|
| **Confidentiality** | Can anyone else read this? | Yes: encryption |
| **Integrity** | Was this changed in transit? | Yes: hashes, MACs, signatures |
| **Availability** | Is the service up when needed? | Mostly no. Crypto can even hurt it (an expired cert is an outage) |

Two more goals matter for PKI: **authentication** (who am I talking to?) and, in some applications, **non-repudiation**. A digital signature can support non-repudiation, but it does not guarantee it by itself: key custody, identity proofing, operational controls, and the legal context also matter. PKI is mostly about authentication.

## 2. Threat model: who are we defending against?

On an open network, assume an attacker can:
- **Eavesdrop**: read traffic → defeated by encryption.
- **Tamper**: modify or inject traffic → defeated by integrity checks.
- **Impersonate / man-in-the-middle (MITM)**: pretend to be the server → defeated by **authentication**, which is where certificates come in.

Encryption alone does not stop a MITM: you would just have a private conversation with the attacker.

## 3. Symmetric vs asymmetric

| | Symmetric | Asymmetric (public-key) |
|---|---|---|
| Keys | One shared secret | Key pair: public + private |
| Speed | Very fast | Slow (100-1000x) |
| Used for | Bulk data encryption | Signatures, key exchange |
| Examples | AES-GCM, ChaCha20-Poly1305 | RSA, ECDSA, Ed25519, ECDH |
| Main problem | How do both sides get the key safely? | Slow; and how do you know whose public key it is? |

## 4. Hashing and signatures

- A **hash** (SHA-256) turns any data into a short fixed fingerprint. One-way; any change alters it completely.
- A **digital signature** = hash the data, then sign the hash with a **private key**. Anyone with the **public key** can verify. It proves *who held the key* and *that the data is unchanged*.

## 5. Hybrid encryption: why TLS uses both

Asymmetric crypto solves the key-distribution problem; symmetric crypto is fast. So protocols combine them:
1. Use asymmetric crypto to **authenticate** and **agree on a fresh shared key** (key exchange).
2. Use that key with symmetric crypto for the actual data.

## 6. The identity problem

A signature proves "the holder of key K signed this". It does not prove K belongs to `bank.example`. Without a way to bind keys to identities, an attacker can simply present their own key and claim to be anyone.

## 7. Certificates and CAs

- A **certificate** is a signed document: *"this public key belongs to this name"*. Format: X.509.
- A **Certificate Authority (CA)** is the party that signs it after applying an issuance policy. That may validate control of a domain, an organisation's identity, a device's identity, or another approved claim.

Authentication is not authorisation: a certificate can identify a peer, but the application still decides what that identity may do.

## 8. Chain of trust and trust stores

You cannot know every CA, so trust is delegated:

```
Root CA        (pre-installed in your trust store; self-signed)
  └─ Intermediate CA   (signed by the root)
       └─ Leaf cert    (the server's certificate, signed by the intermediate)
```

Your OS, browser, or runtime ships a **trust store** of roots. A certificate is accepted if you can follow signatures from it up to one of those roots, and name, dates, and purpose also check out.

## 9. TLS in five lines

1. Client says hello and sends a key share, naming the host it wants (SNI).
2. Server replies with its key share; both derive shared symmetric keys.
3. Server sends its certificate chain and proves it holds the private key by signing the handshake.
4. Client validates the chain, hostname, and dates.
5. Both sides encrypt everything with the symmetric keys. (mTLS: the client also presents a certificate.)

## 10. Glossary

| Term | One line |
|---|---|
| Key pair | Matching public and private keys |
| Hash | Fixed-size fingerprint of data |
| Signature | Hash signed with a private key |
| Certificate | Signed binding of a public key to an identity |
| CA | Entity that signs certificates |
| Chain | Leaf → intermediate → root |
| Trust store | Roots a system accepts |
| TLS / mTLS | Encrypted, authenticated channel (one-way / mutual) |
| CSR | Request for a certificate |
| Revocation | Declaring a certificate no longer valid |

## 11. Where each concept is covered

| Concept | Chapter |
|---|---|
| What goes wrong: rogue roots, compromised CAs, skipped verification | [9. Appendix](09-trust-failures-pinning-and-case-studies.md#when-trust-breaks-deep-dive) |
| Key compromise response | [5. Lifecycle](05-certificate-lifecycle.md#compromise-and-incident-response) |
| Symmetric/asymmetric, signatures, key exchange, forward secrecy, algorithm choice | [1. Crypto foundations](01-crypto-foundations.md) |
| Certificate fields, formats, SAN, EKU | [2. Certificates and X.509](02-certificates-and-x509.md) |
| CAs, chains, trust stores, validation | [3. Trust and chains](03-trust-and-chains.md) |
| CSR, issuance, ACME, renewal, revocation | [5. Lifecycle](05-certificate-lifecycle.md) |
| TLS handshake, mTLS | [4. TLS and mTLS flow](04-tls-and-mtls-flow.md) |
| Real-world uses, pitfalls, debugging | [6. Where you use it](06-where-you-use-it.md) |
| Post-quantum migration, ACME/EST, SPIFFE/SPIRE, CT/CAA | [7. Modern PKI topics](07-modern-pki-and-advanced-topics.md) |

## Recap
- Crypto gives confidentiality and integrity; PKI adds authentication.
- Symmetric is fast, asymmetric solves key distribution; real protocols use both.
- Certificates bind keys to names; CAs and trust stores make that verifiable at scale.
