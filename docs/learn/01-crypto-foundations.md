---
title: 1. Cryptography foundations
parent: Learn path
nav_order: 1
---

# 1. Cryptography Foundations

**Goal:** go one level deeper than the [crash course](00-crash-course.md) on the primitives PKI is built from, and know which algorithms to pick.

## Key ideas

### Security properties and the primitives that give them

| Property | Meaning | Primitive |
|---|---|---|
| Confidentiality | Only intended parties can read | Symmetric encryption (AEAD) |
| Integrity | Changes are detected | Hash, MAC, AEAD tag, signature |
| Authentication | You know who produced it | Signature, MAC (shared key), certificate |
| Non-repudiation | Evidence that can help establish who signed | Asymmetric signature, plus reliable key custody, identity proofing, and relevant legal/operational controls |

### Hashing
A hash function maps any input to a fixed-size digest. Properties: one-way, collision-resistant, small changes alter everything. Use SHA-256 or better; MD5 and SHA-1 are broken for security use. A **MAC / HMAC** is a hash keyed with a shared secret: integrity plus authentication between two parties who share the key.

### Symmetric encryption
One shared secret key encrypts and decrypts. It is fast, so it carries the bulk data. The weakness: both sides must somehow already share the key. Modern ciphers are **AEAD** (authenticated encryption): they encrypt and authenticate in one step, so tampering is detected. Use AES-GCM or ChaCha20-Poly1305, never raw AES-CBC/ECB assembled by hand.

```python
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

key = AESGCM.generate_key(bit_length=256)
nonce = os.urandom(12)                      # must never repeat for the same key
ct = AESGCM(key).encrypt(nonce, b"secret", b"header")
AESGCM(key).decrypt(nonce, ct, b"header")   # raises if tampered
```

### Asymmetric (public-key) cryptography
A **key pair**: a private key you never share, and a public key you hand out freely. It is slow, so it is used for small jobs:

| Job | How it works |
|---|---|
| **Digital signature** | Sign with the private key, anyone verifies with the public key. Proves origin and integrity. |
| **Key exchange** | Two parties derive a shared symmetric key over an open channel (ECDHE). |
| **Encryption** (legacy RSA) | Encrypt with the public key, decrypt with the private key. Modern protocols mostly avoid this. |

Common algorithms: RSA (2048+ bit), ECDSA (P-256), Ed25519.

### Signature in practice
```python
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes

key = ec.generate_private_key(ec.SECP256R1())
sig = key.sign(b"hello", ec.ECDSA(hashes.SHA256()))
key.public_key().verify(sig, b"hello", ec.ECDSA(hashes.SHA256()))  # raises if invalid
```

A valid signature proves that the holder of the private key signed the data and that the data was not altered. It does not, by itself, prove who controlled the key or guarantee legal non-repudiation.

### Key exchange and forward secrecy
**Diffie-Hellman (ECDHE, X25519)**: each side generates a temporary key pair, exchanges the public halves, and both compute the same shared secret. An eavesdropper sees only the public halves and cannot compute it. This is the "authenticate and agree on a key" step of the hybrid pattern: the shared secret then keys the symmetric cipher.

With **ephemeral** keys (the "E"), session keys are discarded after use. If the server's long-term private key is stolen later, **previously recorded traffic stays safe**. This is **forward secrecy**. TLS 1.3 requires it; the certificate key is used only to *sign*, not to protect session keys.

### Randomness
All of this depends on unpredictable keys and nonces. Use the OS CSPRNG (`os.urandom`, `secrets`, `/dev/urandom`), never `random` or a timestamp. Weak randomness (predictable keys, repeated nonces) has broken otherwise sound systems. Be careful with freshly booted VMs, containers, and embedded devices.

### Algorithm and key-size cheat sheet

| Purpose | Prefer | Acceptable | Avoid |
|---|---|---|---|
| Signatures | Ed25519, ECDSA P-256, RSA-PSS | RSA 2048+ with a modern signature scheme | RSA < 2048, DSA, legacy RSA PKCS#1 v1.5 where RSA-PSS is supported |
| Key exchange | X25519, ECDHE P-256 | Finite-field DH 2048+ | Static RSA key transport |
| Symmetric (AEAD) | AES-256-GCM, ChaCha20-Poly1305 | AES-128-GCM | RC4, DES/3DES, ECB, unauthenticated CBC |
| Hash | SHA-256/384, SHA-3 | SHA-512 | MD5, SHA-1 |
| Password storage | Argon2id, scrypt, bcrypt | PBKDF2 | Plain or fast hashes |

Rule of thumb: don't invent or hand-assemble crypto; use a vetted library and protocol (TLS) with current defaults. Ed25519 support varies across TLS, X.509, hardware, and enterprise tooling, so choose an algorithm your complete platform supports. The table is guidance, not a permanent standards requirement; follow current protocol and platform recommendations. Quantum computers threaten RSA and elliptic curves; post-quantum algorithms are being rolled out (hybrid key exchange in TLS is already appearing), but classical-algorithm certificates are what you use today.

## The problem PKI solves
You can now encrypt, sign, and agree on keys. But if you receive a public key over the network, how do you know it belongs to `bank.example` and not an attacker in the middle? A signature only proves "someone holding *this* private key signed this". It says nothing about *who* that is.

**PKI is the system that binds public keys to identities in a way you can verify.**

## Why it matters to you
Almost every "certificate error" is a failure of this binding: the key is not tied to the name you asked for, by an authority you trust, for a purpose and time that are valid.

## Common mistakes
- Treating encryption as authentication. An encrypted channel to the wrong party is still wrong.
- Using a MAC where non-repudiation is needed.
- Weak randomness, nonce reuse, or home-grown protocols.
- Confusing hashing, encryption, and signing.
- Sharing or committing private keys.

## Recap
- Pick primitives by the property you need: AEAD, hash/MAC, signature, key exchange.
- Ephemeral key exchange gives forward secrecy; the certificate key only signs.
- Good randomness and current algorithms matter more than clever design.
- Signatures prove key possession, not identity; PKI binds identity to keys.
