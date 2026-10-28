---
title: 3. Trust and chains
parent: Learn path
nav_order: 3
---

# 3. Trust and Chains

**Goal:** understand why a certificate is trusted, and exactly what a verifier checks.

## Key ideas

### Certificate Authorities
A CA is an entity whose signature you agree to trust. You do not trust each site; you trust a small set of CAs, and they vouch for the rest.

### The chain
```
Root CA (self-signed, in trust store, kept offline)
  └─ Intermediate CA (signed by root, issues day-to-day certs)
       └─ Leaf / end-entity cert (your server or client)
```
- **Root**: self-signed. Trusted because it is pre-installed, not because of a signature.
- **Intermediate**: limits the exposure of the root key and allows rotation or revocation without replacing the root.
- **Leaf**: the cert presented by a server or client.

### Trust stores
A trust store is the set of root certificates a system accepts. The OS, browsers, Java, Python (`certifi`), and containers each may have their own. "Works on my machine, fails in the container" is often a trust store difference.

The configured trust anchor is an input to validation; it is not normally supplied by the server. A server should send the leaf and required intermediates, while the client supplies the trust anchor from its own store. Trust-store contents and update mechanisms differ across operating systems, language runtimes, container images, and embedded devices.

### Path validation
To accept a leaf, the verifier builds a path to a trusted root and checks:
1. Each signature verifies using the next certificate's public key.
2. Every cert is within its validity period (clock matters).
3. Intermediates are CAs (`CA:TRUE`) and the path length is respected.
4. The leaf name matches the requested host (SAN).
5. Key Usage / EKU fit the purpose.
6. If revocation checking is configured and available, no certificate in the path is revoked (see [lifecycle](05-certificate-lifecycle.md)).

Depending on the verifier and its policy, validation may also check critical extensions, name constraints, certificate policies, permitted signature algorithms, and other constraints. Revocation is not equivalent to signature or hostname validation: many clients do not check it, or soft-fail when the revocation service is unavailable.

There may be more than one possible path. Cross-signing, alternate intermediates, and different trust stores can cause two clients to choose different paths or reach different results. When debugging, record the complete chain, the trust store, and the runtime that performed validation rather than assuming that a chain working in one environment will work everywhere.

The server should send the **leaf plus intermediates**, not the root. The client already has the root.

### Self-signed and private CAs
- A **self-signed leaf** is trusted only if you explicitly add it to a trust store (or pin it).
- A **private CA** is the right tool for internal services: create your own root, distribute it to your clients' trust stores, and issue internal certs. Same mechanics as the public web, different trust anchor.

```sh
openssl verify -CAfile root.pem -untrusted intermediate.pem leaf.pem
```

## When trust breaks

The model only works if every link holds. The most common break points are:
- skipped verification (chain and/or hostname),
- an unwanted root in trust stores,
- a compromised or mis-issuing intermediate,
- a compromised or distrusted root, and
- a leaked leaf private key (response in [chapter 5](05-certificate-lifecycle.md#compromise-and-incident-response)).

For full attack paths, pinning trade-offs, and case studies, see [Appendix: Trust failures, pinning, and case studies](09-trust-failures-pinning-and-case-studies.md).

### Defences at a glance

| Defence | What it protects against |
|---|---|
| Real verification (chain + hostname) | Most client-side trust failures |
| Minimal, app-scoped trust stores | Rogue or unneeded roots |
| Name constraints on private CAs | Internal CA abuse across names |
| Offline roots, HSM-protected CA keys | CA key theft |
| Short lifetimes + automation | Stolen or mis-issued certs staying useful |
| Certificate Transparency monitoring | Detecting mis-issuance for your domains |
| CAA DNS records | Limits which public CAs may issue for your domain |
| Pinning (public key or CA) | Rogue CAs in clients you control |
| Vendor blocklists (OneCRL, CRLSet) | Fast removal of compromised intermediates |

## Why it matters to you
Choosing public versus private CA, deciding what to put in a trust store, and fixing "unable to get local issuer certificate" all come from this model.

## Common mistakes
- Server not sending intermediates (works in browsers that cache or fetch them, fails in curl or code).
- Disabling verification instead of trusting the right CA.
- Adding a broad root to every trust store when a narrowly scoped one would do.

## Recap
- Trust flows from a small set of roots through signed chains.
- Verification = signatures + validity + name + purpose + revocation.
- Skipping verification or trusting a rogue root gives an attacker silent MITM; a compromised intermediate or root lets them mint valid certs.
- Send leaf + intermediates; clients hold roots.
