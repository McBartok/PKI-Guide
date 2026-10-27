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
| `a.example.com` with `*.example.com` | Matches one label only; it does not match `a.b.example.com` |
| A service identity URI | URI SAN, when the protocol defines identity that way |

### Extensions that change behaviour
- **Basic Constraints** `CA:TRUE/FALSE` (and path length): may this cert sign other certs?
- **Key Usage** (digitalSignature, keyCertSign, ...): permitted key operations.
- **Extended Key Usage** (serverAuth, clientAuth, codeSigning): permitted purpose.
- **Authority/Subject Key Identifier**: helps link a cert to its issuer.
- **CRL Distribution Points / Authority Information Access**: where to find revocation info and the issuer cert.

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
| **Private key** | Never share. `.key`, or PKCS#8 PEM. |
| **CSR** | Certificate Signing Request: your public key + requested subject/SANs, signed by your private key. |
| **PKCS#12 (.p12/.pfx)** | Bundle of key + cert chain, password protected. Common in Java/Windows. |
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
