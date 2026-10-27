---
title: Trust failures, pinning, and case studies
parent: Reference
nav_order: 2
---

# 7. Appendix: Trust failures, pinning, and case studies

**Goal:** deep dive on failure modes, defensive controls, and notable incidents.

This appendix expands [Trust and chains](../learn/03-trust-and-chains.md). Read chapter 3 first for the core model.

## When trust breaks (deep dive)

The model only works if every link holds. Each failure below lets an attacker present a certificate your client accepts for a name they do not own. Most also require the attacker to sit on the network path (MITM), but on open networks that is a realistic assumption.

### 1. You don't verify the chain or hostname
`verify=False`, `InsecureSkipVerify: true`, `curl -k`, a custom "trust everything" TrustManager, or skipping the hostname check.
- **Result:** any certificate is accepted, even self-signed or issued for another site. The connection is still encrypted, but to the attacker, who relays to the real server and reads or modifies everything (passwords, tokens, API calls, software updates).
- **Subtle variant:** verifying the chain but not the hostname. Any valid certificate for *any* site then works, and those are free.
```python
import requests
requests.get("https://api.example.com", verify=False)   # no authentication at all
requests.get("https://api.example.com")                 # default: chain + hostname checked
requests.get("https://api.example.com", verify="internal-root.pem")  # right fix for a private CA
```
- **Why it is common:** it "fixes" the error in dev and then ships. Fix the trust (add the right CA) instead.

### 2. A malicious or unwanted root enters your trust store
Whoever controls a trusted root can mint a valid certificate for **any** name, and the client shows no warning.
- **Vectors:** corporate TLS-inspection proxies (legitimate but powerful), malware, "install this CA to make it work" instructions, developer tooling and local dev CAs left installed, vendor-preinstalled roots, compromised base images or CI runners, and state-mandated roots.
- **Result:** silent, full MITM of all TLS from that machine, including HTTPS to your bank or package registry.
- **Defences:** keep trust stores minimal; scope private roots per application instead of OS-wide; audit and diff trust stores in images; restrict who can modify them; use name constraints on private CAs; monitor with Certificate Transparency (CT) where public CAs are involved. Note that CT does not see certificates from a locally-installed root.

### 3. An intermediate CA is compromised or mis-issues
An attacker holding an intermediate's private key can mint valid leaf certificates for any name that CA is allowed to issue.
- **Blast radius** = everything that intermediate can issue (and what name constraints and path length permit), not the whole PKI. This is why roots stay offline and intermediates do the work.
- **Response:** in public ecosystems, the intermediate may be revoked and blocked by browser/OS vendors (for example via Mozilla's OneCRL or Chrome's CRLSet), and the certs it issued must be reissued from a new intermediate. Private PKIs and embedded systems usually need their own containment and trust-store update process. The root does not necessarily need replacing.
- **Catch:** clients that do not receive vendor blocklists (embedded devices, custom builds, system stores that lag) keep trusting it.

### 4. A root CA is compromised or distrusted
Everything it ever signed becomes suspect. Root programs (Mozilla, Chrome, Apple, Microsoft) can remove it from trust stores, but this takes updates, breaks legitimate sites, and is why distrust is usually phased (for example, by distrusting only certs issued after a date).

### 5. A leaf private key is compromised
Covered in [chapter 5](../learn/05-certificate-lifecycle.md#compromise-and-incident-response): the impact is limited to that name, but revocation is weak, so replace the key and keep lifetimes short.

## Pinning

**Pinning** means your client accepts only an expected certificate or key for a given server, instead of any certificate that chains to any trusted root. It is checked *in addition to* normal chain validation.

### What you can pin

| Pin | Survives renewal? | Notes |
|---|---|---|
| **Leaf certificate** | No: changes every renewal | Simple but brittle. Fine for a fixed internal peer or device. |
| **Leaf public key (SPKI hash)** | Only if you reuse the key | The common choice. Reusing keys conflicts with key rotation advice. |
| **Intermediate or root CA (public key)** | Yes, while you stay with that CA | Better operationally than leaf pinning. |
| **Backup pin** | n/a | A second key you hold in reserve so you can rotate without locking clients out. |

### What it gives you
- **Protection from rogue or compromised CAs.** A certificate from a malicious root in the trust store, a mis-issuing CA, or a stolen intermediate fails the pin check even though it validates perfectly.
- **Protection from locally-installed roots**, such as malware or an inspection proxy on the user's machine, which Certificate Transparency cannot see.
- **A much smaller trusted set**: one key or CA instead of the hundreds in a trust store.

### What it costs
- **Outage risk.** If you rotate a key or switch CAs without updating the pins, every pinned client fails.
- **Operational weight.** Pins are a second thing to keep in sync with automated renewal.
- **Blocks legitimate interception** (corporate proxies, debugging tools). That may be what you want, but be deliberate.
- **Does not replace verification.** Pin *and* validate; the pin only narrows what is acceptable.
- **Only protects the client you control.** It is for apps and services you build and can update, not for general browsing.

### History: why browsers dropped it
HTTP Public Key Pinning (HPKP) let websites tell browsers which keys to pin. It was removed, because a mistake or an attacker who briefly controlled a site could lock users out for months. Chrome and others rely on Certificate Transparency, CAA, and vendor blocklists instead. Pinning today is mainly a client-side choice in mobile apps, thick clients, and service-to-service connections.

### How: pin the public key hash
Hash the Subject Public Key Info (SPKI), which stays the same if the key is reused across renewals:
```sh
openssl s_client -connect api.example.com:443 -servername api.example.com </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary | base64
```
Check it after the normal handshake has validated the chain:
```python
import base64, hashlib, socket, ssl
from cryptography import x509
from cryptography.hazmat.primitives import serialization

PINS = {"<base64 sha256 of current key>", "<base64 sha256 of backup key>"}

ctx = ssl.create_default_context()  # normal chain + hostname checks stay on
with socket.create_connection(("api.example.com", 443)) as sock:
    with ctx.wrap_socket(sock, server_hostname="api.example.com") as tls:
        cert = x509.load_der_x509_certificate(tls.getpeercert(binary_form=True))
        spki = cert.public_key().public_bytes(
            serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
        if base64.b64encode(hashlib.sha256(spki).digest()).decode() not in PINS:
            raise ssl.SSLError("pin mismatch")
```
Prefer your platform's built-in support where it exists (Android Network Security Config, iOS App Transport Security / `URLSession` pinning, OkHttp `CertificatePinner`), since those handle chains and failures correctly.

## Case studies

| Incident | What happened | Lesson |
|---|---|---|
| **DigiNotar (2011)** | Dutch CA breached; attackers issued rogue certs including for `*.google.com`, used for MITM of users in Iran. | A single CA compromise affects every site. |
| **Comodo reseller (2011)** | An attacker compromised a registration authority account and obtained fraudulent certs for major domains. | Weak points can be in a CA's partners, not just its CA keys. |
| **Symantec (2015-2018)** | Repeated mis-issuance and audit failures led Chrome and Mozilla to phase out trust in Symantec roots. | Root programs can distrust a very large CA on a schedule. |
| **Superfish / eDellRoot (2015)** | Laptops shipped with preinstalled roots whose private keys were included or easily extracted, allowing anyone to MITM those users. | A root you did not choose, whose key is not protected, is a skeleton key. |
| **Kazakhstan root (2019)** | The government tried to make citizens install a root CA to intercept HTTPS; browsers blocked it. | Trust-store changes are an attack surface. |
| **eMudhra / emSign (October 2026)** | Private keys for multiple intermediates became recoverable. | Key generation quality matters; fast blocklists do not reach every client equally fast. |

### eMudhra intermediate key compromise (October 2026, dated case study)
Status note: this summary reflects public information available as of **2026-10-27** and may evolve.

This case is based on the Mozilla Bugzilla report ([bug 2083449](https://bugzilla.mozilla.org/show_bug.cgi?id=2083449)) and Mozilla's [security blog post](https://blog.mozilla.org/security/2026/10/20/protecting-firefox-users-following-the-compromise-of-emudhra-intermediate-certificates/).

- **What:** a researcher reported on 17 October 2026 that private keys of eight eMudhra intermediate CA certificates could be recovered.
- **Why it worked:** per the report, a flaw in key generation made keys practically recoverable.
- **Impact:** anyone with those keys could issue valid certs for many sites and impersonate them when able to intercept traffic.
- **Response:** major browser ecosystems pushed blocklist/revocation updates quickly; the affected intermediates were revoked.
- **What to learn:** vendor blocklists can contain damage fast, but runtimes that do not receive timely trust-store or blocklist updates may remain exposed longer.
