---
title: 2. Certificates and X.509
parent: Learn path
nav_order: 2
---

# 2. Certificates and X.509

**Goal:** know what a certificate is, what fields matter, and how to recognise the files you handle.

## Key ideas

A certificate is a signed statement: *"the CA vouches that this public key is associated with this subject under the CA's issuance policy."* The standard format is **X.509**.

### Fields that matter

| Field | Meaning |
|---|---|
| Subject | Who the certificate is for. The CN is legacy; do not rely on it. |
| **Subject Alternative Name (SAN)** | The DNS names, IPs, URIs, or emails the cert is valid for. Hostname checks use this. |
| Public key | The key being vouched for. |
| Issuer | The CA that signed it. |
| Validity | `notBefore` / `notAfter`. |
| Serial number | Unique per issuer; used for revocation. |
| Signature | The issuer's signature over all of the above. |

For hostname validation, the SAN type must match the name being checked:

| Connection name | Required SAN |
|---|---|
| `api.example.com` | DNS SAN |
| `10.0.0.5` | IP address SAN, not a DNS SAN containing the text `10.0.0.5` |
| `a.example.com` with `*.example.com` | Matches one label only; it does not match `a.b.example.com` or the bare `example.com` |
| A service identity URI | URI SAN, when the protocol defines identity that way |

### Extensions that change behaviour
- **Basic Constraints** `CA:TRUE/FALSE` (and path length): may this cert sign other certs?
- **Key Usage** (digitalSignature, keyCertSign, ...): permitted key operations.
- **Extended Key Usage** (serverAuth, clientAuth, codeSigning): permitted purpose.
- **Authority/Subject Key Identifier**: helps link a cert to its issuer.
- **CRL Distribution Points / Authority Information Access**: where to find revocation info and the issuer cert.

### What a real certificate looks like
This is the server certificate from the [hands-on lab](11-hands-on-lab.md), printed with `openssl x509 -in server.pem -noout -text` (long hex values shortened):

```text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 79:73:7b:ca:...:9e:05:4d       ← unique per issuer; used in revocation lists
        Signature Algorithm: ecdsa-with-SHA256        ← how the issuer signed this certificate
        Issuer: CN=Lab Intermediate CA                ← who signed it (the next link in the chain)
        Validity
            Not Before: Nov  5 09:51:22 2026 GMT      ← not valid before this...
            Not After : Dec  5 09:51:22 2026 GMT      ← ...or after this
        Subject: CN=localhost                         ← who it is for; the CN is ignored for hostname checks
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey      ← the key being vouched for (EC P-256)
                Public-Key: (256 bit)
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Basic Constraints: critical
                CA:FALSE                              ← a leaf: may not sign other certificates
            X509v3 Key Usage: critical
                Digital Signature                     ← the key may sign (e.g. CertificateVerify)
            X509v3 Extended Key Usage:
                TLS Web Server Authentication         ← serverAuth: valid for TLS servers only
            X509v3 Subject Alternative Name:
                DNS:localhost, IP Address:127.0.0.1   ← THE names hostname checks use
            X509v3 Subject Key Identifier: 47:93:13:...
            X509v3 Authority Key Identifier: AA:11:35:... ← matches the issuer's SKI (chapter 3)
    Signature Algorithm: ecdsa-with-SHA256
    Signature Value: 30:45:02:21:...                  ← the issuer's signature over everything in "Data"
```

`critical` means a verifier that does not understand the extension must reject the certificate rather than ignore it.

### Inspecting a certificate
```sh
openssl x509 -in cert.pem -noout -subject -issuer -dates -ext subjectAltName,basicConstraints,extendedKeyUsage
```
```python
from cryptography import x509
cert = x509.load_pem_x509_certificate(open("cert.pem", "rb").read())
print(cert.subject, cert.issuer, cert.not_valid_after_utc)
print(cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value)
```

### Files and formats

| Thing | Notes |
|---|---|
| **PEM** | Base64 text with `-----BEGIN ...-----` headers. Most common. |
| **DER** | Binary form of the same data. |
| **Private key** | Never share. Often `.key`; PEM headers include `PRIVATE KEY` (PKCS#8), `RSA PRIVATE KEY` (PKCS#1), or `EC PRIVATE KEY` (SEC1). |
| **CSR** | Certificate Signing Request: your public key + requested subject/SANs, signed by your private key. |
| **PKCS#12 (.p12/.pfx)** | Bundle of key + cert chain, usually password protected. Common in Java/Windows. Files created with legacy encryption (RC2/3DES) may need `-legacy` in OpenSSL 3. |
| **.crt / .cer / .pem** | Extensions are only convention; check the content. |

## Why it matters to you
Hostname validation, client authorisation, and "why was my cert rejected" all come down to SAN, validity, and key usage fields.

## Common mistakes
- Putting the hostname only in CN, with no SAN.
- Missing `serverAuth` / `clientAuth` EKU for the intended use.
- Mixing up the cert, the key, and the chain file.

## Recap
- A certificate = public key + an identity claim evaluated under an issuance policy + issuer signature.
- SAN is what hostnames are matched against.
- Extensions limit what a certificate may be used for.

## Check your understanding

1. A certificate has `CN=api.example.com` and no SAN. Will modern clients accept it for `api.example.com`?
2. Does `*.example.com` cover `example.com`? Does it cover `v2.api.example.com`?
3. You connect to `https://10.0.0.5`. The certificate's SAN is `DNS:10.0.0.5`. Will it validate?
4. A file is called `server.crt`. Is it PEM or DER?

<details markdown="block">
<summary>Answers</summary>

1. No. Browsers and most libraries ignore CN for hostname checks; the name must be in the SAN.
2. No to both. A wildcard matches exactly one label.
3. No. An IP address must be in an IP address SAN, not a DNS SAN.
4. You can't tell from the extension. Open it: PEM starts with `-----BEGIN CERTIFICATE-----`, DER is binary.

</details>
