---
title: 0. Crash course
parent: Learn path
nav_order: 0
---

# 0. Crash Course: The Whole Picture in One Sitting

**Goal:** get a working mental model of everything in this guide, shallowly. Chapters 1-6 revisit each piece in depth. If you already know this material, skip to [chapter 1](01-crypto-foundations.md).

**New to TLS?** A good route is: this crash course → chapters 2, 3, and 4 → the [hands-on lab](11-hands-on-lab.md) → chapter 5. Chapter 1 has reference material you can come back to.

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
- A **digital signature** is computed over the data (in practice over a hash of it) with a **private key**. Anyone with the **public key** can verify. It proves *that the holder of the private key signed it* and *that the data is unchanged*.

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

**An analogy: passports.** A passport (certificate) binds a photo (public key) to a name. It is trusted because a government you recognise (CA) issued it, and the border officer has a list of genuine government seals (trust store). The officer checks the seal, the expiry date, and that the photo matches the person in front of them. That last check is proof of possession: in TLS, the server proves it holds the private key. A stolen passport is useless if your face does not match, and a copied certificate is useless without the private key. Like any analogy it breaks down eventually, but it is a good first mental model.

## 8. Chain of trust and trust stores

You cannot know every CA, so trust is delegated:

```
Root CA        (pre-installed in your trust store; self-signed)
  └─ Intermediate CA   (signed by the root)
       └─ Leaf cert    (the server's certificate, signed by the intermediate)
```

Your OS, browser, or runtime ships a **trust store** of roots. A certificate is accepted if you can follow signatures from it up to one of those roots, and name, dates, and purpose also check out.

## 9. TLS in five lines

1. Client says hello, naming the host it wants (SNI), and sends a **key share** (the public half of a temporary key pair, used only for this connection).
2. Server replies with its key share; both combine the shares to derive the same symmetric keys. Nobody watching can compute them, but the client does not yet know *who* it is talking to.
3. Server sends its certificate chain and proves it holds the private key by signing the handshake.
4. Client validates the chain, hostname, dates, and that signature. If anything fails, it hangs up.
5. Both sides encrypt everything with the symmetric keys. (mTLS: the client also presents a certificate.)

[Chapter 4](04-tls-and-mtls-flow.md#the-handshake-step-by-step-from-the-clients-point-of-view) walks through this step by step, and the [hands-on lab](11-hands-on-lab.md) lets you watch it happen.

## 10. Glossary

| Term | One line |
|---|---|
| Key pair | Matching public and private keys |
| Hash | Fixed-size fingerprint of data |
| Signature | Proof, made with a private key, that data came from the key holder unchanged |
| Key share | Public half of a temporary key pair used to agree on session keys |
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
| Symmetric/asymmetric, signatures, key exchange, forward secrecy, algorithm choice | [1. Crypto foundations](01-crypto-foundations.md) |
| Certificate fields, formats, SAN, EKU | [2. Certificates and X.509](02-certificates-and-x509.md) |
| CAs, chains, trust stores, validation | [3. Trust and chains](03-trust-and-chains.md) |
| TLS handshake, mTLS | [4. TLS and mTLS flow](04-tls-and-mtls-flow.md) |
| CSR, issuance, ACME, renewal, revocation | [5. Lifecycle](05-certificate-lifecycle.md) |
| Key compromise response | [5. Lifecycle](05-certificate-lifecycle.md#compromise-and-incident-response) |
| Real-world uses and pitfalls | [6. Where you use it](06-where-you-use-it.md) |
| Post-quantum migration, ACME/EST, SPIFFE/SPIRE, CT/CAA | [7. Modern PKI topics](07-modern-pki-and-advanced-topics.md) |
| Debugging commands and common errors | [8. Debugging cheat sheet](08-debugging-cheat-sheet.md) |
| What goes wrong: rogue roots, compromised CAs, skipped verification | [9. Appendix](09-trust-failures-pinning-and-case-studies.md#when-trust-breaks-deep-dive) |
| Build a PKI, serve HTTPS, and cause common errors yourself | [11. Hands-on lab](11-hands-on-lab.md) |

## Recap
- Crypto gives confidentiality and integrity; PKI adds authentication.
- Symmetric is fast, asymmetric solves key distribution; real protocols use both.
- Certificates bind keys to names; CAs and trust stores make that verifiable at scale.

## Check your understanding

1. Why doesn't encryption alone protect you from a man-in-the-middle?
2. Why does TLS use both asymmetric and symmetric cryptography?
3. What does a certificate add that a bare public key does not?

<details markdown="block">
<summary>Answers</summary>

1. You could be encrypting to the attacker. Without authentication, you don't know whose key you agreed on.
2. Asymmetric crypto lets two strangers authenticate and agree on a key over an open network; symmetric crypto is much faster for the actual data.
3. A CA's signed statement that the key belongs to a specific name, which you can check against a trust store.

</details>
