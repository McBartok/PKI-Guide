---
title: 5. Certificate lifecycle
parent: Learn path
nav_order: 5
---

# 5. Certificate Lifecycle

**Goal:** follow a certificate from key generation to retirement, and see why automation matters.

## Key ideas

### Stages
```text
        YOU (or your automation)                          THE CA
 ┌─────────────────────────────────┐
 │ 1. Generate key pair            │
 │    (private key stays here)     │
 │ 2. Create CSR ──────────────────┼──────────►  3. Validate the request
 └─────────────────────────────────┘                (domain control, identity, ...)
                                                    4. Sign and return cert + chain
 ┌─────────────────────────────────┐                        │
 │ 5. Deploy key + cert + chain,   │◄───────────────────────┘
 │    reload the service           │
 │ 6. Monitor expiry               │
 │         │                       │
 │         ▼                       │
 │    Renew before expiry ─────────┼──► back to 1 (fresh key) or 2
 │         │                       │
 │    Key compromised? ────────────┼──────────►  Revoke (CRL, OCSP if offered)
 └─────────────────────────────────┘
       Not renewed: the certificate expires and clients reject it (outage)
```

1. **Generate a key pair** on the system that will use it. The private key should never leave it if avoidable.
2. **Create a CSR**: your public key and requested names, signed with your private key (proof of possession).
3. **Validation**: the CA applies its issuance policy. For public DV certificates this usually means proving control of the names (DNS, HTTP, or TLS-ALPN challenge); other public and internal CAs may validate an organisation, device, service identity, or another claim.
4. **Issue**: the CA signs and returns the certificate and chain.
5. **Deploy**: install key, leaf, and intermediates; reload the service.
6. **Renew/rotate** before expiry, ideally with a fresh key.

Protect private keys throughout this process: generate them on the target system when practical, restrict file and service-account access, encrypt them when unattended startup permits it, and keep them out of source control, container images, logs, and ordinary backups. Use a secret manager, KMS, or HSM when the threat model and operational requirements justify it.

```sh
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
  -keyout server.key -out server.csr -subj "/CN=svc.example.com" \
  -addext "subjectAltName=DNS:svc.example.com"
openssl req -in server.csr -noout -text   # inspect the request
```
`-noenc` leaves the key unencrypted on disk (OpenSSL 3; older versions use `-nodes`), so protect the file as described above. A CA may ignore or override requested fields; it decides what goes in the issued cert.

### Automation: ACME
ACME (used by Let's Encrypt and others) automates validation, issuance, and renewal. A client proves control of a domain (HTTP-01, DNS-01, TLS-ALPN-01) and receives a certificate. DNS-01 supports wildcards. Tools: certbot, acme.sh, Caddy, cert-manager.

### Lifetimes
Validity periods are shrinking. Under CA/Browser Forum ballot SC-081, the maximum lifetime of a public TLS certificate is:

| Issued from | Maximum validity |
|---|---|
| 15 March 2026 | 200 days |
| 15 March 2027 | 100 days |
| 15 March 2029 | 47 days |

The period for which a CA may reuse a domain-validation result shrinks in parallel, down to 10 days in 2029. Some CAs already offer much shorter certificates (Let's Encrypt offers 6-day certificates). Short lifetimes limit the damage from key compromise and make revocation less critical, but only work if renewal is automated. Private CAs set their own lifetimes.

### Revocation
What if a key is compromised before expiry?
- **CRL**: the CA publishes a signed list of revoked serials. Can be large, but CAs can split them (partitioned CRLs). Public CAs must publish CRLs.
- **Browser-pushed revocation**: browsers aggregate CRLs and push compact updates to clients (Firefox CRLite, Chrome CRLSet). This is where public-web revocation checking is heading.
- **OCSP**: ask the CA about one cert's status. Adds latency and leaks which sites you visit to the CA. Since 2023 OCSP is optional for public CAs, and some large CAs have dropped it (Let's Encrypt shut down its OCSP service in 2025). It is still common in private and enterprise PKI.
- **OCSP stapling**: the server attaches a recent signed OCSP response to the handshake. It fixes OCSP's latency and privacy issues but only works where the CA still runs OCSP; OCSP Must-Staple is effectively deprecated.
- In practice, client revocation checking is inconsistent (soft-fail is common, and many non-browser clients do not check at all), which is a major reason for short-lived certs.

### Expiry
Expired certificates are one of the most common causes of outages. Monitor expiry dates, alert well ahead of time, and automate renewal.

## Compromise and incident response

What if the private key leaks, or a CA mis-issues? (CA-level failures and case studies: [appendix](09-trust-failures-pinning-and-case-studies.md).)

### Leaf key compromised
- **Impact:** the attacker can impersonate that name (with a MITM position) until the certificate expires or is blocked. They can decrypt recorded traffic only if sessions did not use forward secrecy (for example TLS 1.2 with static RSA key exchange). Full TLS 1.3 handshakes always use ephemeral key exchange; resumed sessions instead depend on the server's session-ticket keys (see [chapter 1](01-crypto-foundations.md#key-exchange-and-forward-secrecy)). If the key was used for mTLS client authentication, the attacker can also impersonate that client.
- **Why it lingers:** revocation is soft-fail in many clients, so a revoked certificate may still be accepted. Short lifetimes shrink the window; replacing the key is what actually ends the exposure.

### Playbook
1. **Detect and confirm.** Source: secret scanning, an incident, a CA notice, or CT monitoring showing a certificate you did not request.
2. **Scope.** Which certificates and keys? Which hosts, services, or devices hold them? Was the key reused or copied elsewhere? What can an attacker with it do (which names, client or server auth)?
3. **Generate new keys.** A new certificate on the *same* key fixes nothing.
4. **Reissue and deploy** to every place the old one lived; reload services.
5. **Revoke** the old certificate with the CA (reason `keyCompromise`). Revoking after redeployment avoids an outage. If the key is being actively abused, revoke immediately and accept the disruption. Public CAs must revoke within 24 hours of a confirmed key-compromise report, whoever reports it.
6. **Check for abuse.** Search CT logs for unexpected certificates for your names; review logs for use of the old key, and rotate anything it protected (tokens, sessions).
7. **Fix the cause**, then record what happened: where the key was stored, who could read it, and why rotation was slow.

If *your own private CA* is compromised, stop issuing first. What comes next depends on which CA it is:
- **Intermediate CA:** have the root revoke it, create a new intermediate, and reissue everything the old one signed. Clients that check revocation, or that you can update, stop trusting the old intermediate.
- **Root CA:** a root is self-signed, so nothing above it can revoke it. Remove it from every trust store, distribute a new root, and reissue the entire hierarchy.

Both are far slower than rotating a leaf, so protect CA keys (offline root, HSM, name constraints, few people with access).

If a *public CA you use* is distrusted: you have a deadline to replace the certificates, so keep inventory of which CA issued what, and keep automation CA-agnostic.

### Detection
- **Certificate Transparency (CT):** public CAs log certificates. Monitor logs for your domains (crt.sh, CT monitors) to spot mis-issuance.
- **CAA DNS records:** state which CAs may issue for your domain; public CAs have been required to check them since 2017.
- **Alerting** on unexpected issuance, expiry, and private-key access.

### Hardening to limit damage
Short lifetimes, per-service keys (never shared across hosts), keys in an HSM, KMS, or secret manager rather than in git or images, and least-privilege access to keys.

### Operational checklist
- Keep an inventory of certificates, private keys, issuers, SANs, owners, deployment locations, and expiry dates.
- Test renewal and service reloads before the production expiry window.
- Search container images, backups, configuration stores, and devices for copies of certificates and keys.
- Record which runtime trust store each service uses and how it receives trust-store updates.
- Rotate keys when policy or incident response requires it; renewing a certificate alone does not replace a compromised key.
- Verify that old certificates and keys are removed or disabled after a successful deployment.

## Why it matters to you
You own the private key and the renewal process. A cert that is perfect on day one still causes an outage on its expiry date if nothing renews it, and as lifetimes shrink, that date arrives sooner.

## Common mistakes
- Manual renewal with only a calendar reminder.
- Renewing the cert but not reloading the service.
- Reusing the same private key forever, or copying it across many hosts.
- Forgetting certificates embedded in config, secrets, or devices.

## Recap
- Key → CSR → CA validation → issuance → deploy → renew.
- Automate with ACME or an internal equivalent.
- Revocation is weak in practice and OCSP is being phased out on the public web; prefer short lifetimes and protect keys.
- If a key leaks, replace the key (not just the certificate), revoke, and check CT.

## Check your understanding

1. Why does the CSR contain your public key but not your private key, and why is it signed?
2. You renewed a certificate, but browsers still show the old expiry date. What did you probably forget?
3. Your private key leaked. Is getting a new certificate for the same key enough?
4. Why are short certificate lifetimes considered a replacement for reliable revocation?

<details markdown="block">
<summary>Answers</summary>

1. The CA only needs the public key to put in the certificate; the private key never leaves your system. The signature proves you hold the matching private key.
2. Reloading or restarting the service, or deploying the new certificate to every load balancer or host that serves the name.
3. No. The attacker still has the key, and the new certificate vouches for it. Generate a new key, then reissue and revoke the old certificate.
4. Many clients do not check revocation or soft-fail. A certificate that expires in days limits misuse whether or not revocation is checked.

</details>
