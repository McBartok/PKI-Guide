---
title: 10. Glossary
parent: Learn path
nav_order: 10
---

# 10. Glossary

- **ACME**: protocol for automated certificate issuance and renewal.
- **AEAD**: authenticated encryption; encrypts and detects tampering in one step (AES-GCM, ChaCha20-Poly1305).
- **AIA (Authority Information Access)**: certificate extension pointing to the issuer's certificate (and OCSP, if any); lets clients fetch missing intermediates.
- **CA**: authority whose signature is trusted to vouch for identities.
- **CAA**: DNS record listing which public CAs may issue certificates for a domain.
- **Chain**: leaf → intermediate(s) → root.
- **CRL**: signed list of revoked certificate serial numbers published by a CA.
- **CRLite / CRLSet**: compact revocation data pushed to browsers by Firefox / Chrome.
- **CSR**: request containing a public key and requested names.
- **CT (Certificate Transparency)**: public append-only logs of issued certificates, used to detect mis-issuance.
- **ECH (Encrypted Client Hello)**: TLS extension that encrypts SNI and the rest of the ClientHello.
- **EKU**: permitted purposes of a certificate.
- **Forward secrecy**: stealing a long-term key later does not decrypt previously recorded sessions.
- **HSM**: hardware security module; hardware that stores keys and performs operations without exporting them.
- **Intermediate CA**: CA certificate signed by a root (or another intermediate) that issues leaf certificates.
- **Key share**: the public half of a temporary key pair sent in the TLS handshake; both sides combine key shares to derive session keys.
- **Leaf / end-entity certificate**: the certificate for a server, client, or device; it cannot sign other certificates.
- **MAC / HMAC**: a tag computed with a shared secret key that proves integrity and origin between key holders; HMAC is the common hash-based MAC.
- **ML-KEM / ML-DSA**: NIST post-quantum algorithms for key exchange / signatures.
- **mTLS**: both client and server authenticate with certificates.
- **Nonce**: "number used once"; a value that must never repeat with the same key.
- **OCSP**: protocol to ask a CA about one certificate's revocation status; being phased out on the public web.
- **OCSP stapling**: server includes a recent OCSP response in the handshake.
- **Pinning**: client accepts only specific keys or CAs for a server, in addition to normal validation.
- **Root CA**: self-signed CA certificate trusted because it is in a trust store.
- **SAN**: names a certificate is valid for.
- **SNI**: hostname sent by the client in the handshake.
- **SPKI**: Subject Public Key Info; the encoded public key in a certificate, commonly hashed for pinning.
- **SVID**: SPIFFE Verifiable Identity Document; a workload identity, often an X.509 certificate with a `spiffe://` URI SAN.
- **Transcript**: the hash of all TLS handshake messages so far; CertificateVerify and Finished cover it.
- **Trust anchor**: a certificate or key a verifier trusts by configuration rather than by signature; usually a root.
- **Trust store**: the set of trust anchors a system, browser, or runtime accepts.
