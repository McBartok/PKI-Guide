---
title: 5. Certificate lifecycle
parent: Learn path
nav_order: 5
---

# 5. Certificate Lifecycle

**Goal:** follow a certificate from key generation to retirement, and see why automation matters.

## Key ideas

### Stages
```
generate key → create CSR → CA validates → issue cert → deploy → renew/rotate → (revoke) → expire
```

1. **Generate a key pair** on the system that will use it. The private key should never leave it if avoidable.
2. **Create a CSR**: your public key and requested names, signed with your private key (proof of possession).
3. **Validation**: the CA applies its issuance policy. For public DV certificates this usually means proving control of the names (DNS, HTTP, or TLS-ALPN challenge); other public and internal CAs may validate an organisation, device, service identity, or another claim.
4. **Issue**: the CA signs and returns the certificate and chain.
5. **Deploy**: install key, leaf, and intermediates; reload the service.
6. **Renew/rotate** before expiry, ideally with a fresh key.

Protect private keys throughout this process: generate them on the target system when practical, restrict file and service-account access, encrypt them when unattended startup permits it, and keep them out of source control, container images, logs, and ordinary backups. Use a secret manager, KMS, or HSM when the threat model and operational requirements justify it.

```sh
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -keyout server.key -out server.csr -subj "/CN=svc.example.com" \
  -addext "subjectAltName=DNS:svc.example.com"
openssl req -in server.csr -noout -text   # inspect the request
```
Note that a CA may ignore or override requested fields; it decides what goes in the issued cert.

### Automation: ACME
ACME (used by Let's Encrypt and others) automates validation, issuance, and renewal. A client proves control of a domain (HTTP-01, DNS-01, TLS-ALPN-01) and receives a certificate. DNS-01 supports wildcards. Tools: certbot, acme.sh, Caddy, cert-manager.

### Lifetimes
Validity periods are shrinking (public certs are moving toward very short lifetimes). Short lifetimes limit the damage from key compromise and make revocation less critical, but only work if renewal is automated.

### Revocation
What if a key is compromised before expiry?
- **CRL**: the CA publishes a signed list of revoked serials. Can be large and slow.
- **OCSP**: ask the CA about one cert's status. Adds latency and a privacy leak.
- **OCSP stapling**: the server attaches a recent signed OCSP response to the handshake.
- In practice, client revocation checking is inconsistent (soft-fail is common), which is a major reason for short-lived certs.

### Expiry
Expired certificates are one of the most common causes of outages. Monitor expiry dates, alert well ahead of time, and automate renewal.

## Compromise and incident response

What if the private key leaks, or a CA mis-issues? (CA-level failures and case studies: [appendix](../reference/07-trust-failures-pinning-and-case-studies.md).)

### Leaf key compromised
- **Impact:** the attacker can impersonate that name (with a MITM position) until the certificate expires or is blocked. They can decrypt recorded traffic only if sessions did not use forward secrecy (TLS 1.3 always does; see [chapter 1](01-crypto-foundations.md)).
- **Why it lingers:** revocation is soft-fail in many clients, so a revoked certificate may still be accepted. Short lifetimes shrink the window; replacing the key is what actually ends the exposure.

### Playbook
1. **Detect and confirm.** Source: secret scanning, an incident, a CA notice, or CT monitoring showing a certificate you did not request.
2. **Scope.** Which certificates and keys? Which hosts, services, or devices hold them? Was the key reused or copied elsewhere? What can an attacker with it do (which names, client or server auth)?
3. **Generate new keys.** A new certificate on the *same* key fixes nothing.
4. **Reissue and deploy** to every place the old one lived; reload services.
5. **Revoke** the old certificate with the CA (reason `keyCompromise`).
6. **Check for abuse.** Search CT logs for unexpected certificates for your names; review logs for use of the old key, and rotate anything it protected (tokens, sessions).
7. **Fix the cause**, then record what happened: where the key was stored, who could read it, and why rotation was slow.

If *your own private CA* is compromised: stop issuing, revoke the CA, issue a new CA, redistribute the new root to every trust store, and reissue everything it signed. This is far slower than rotating a leaf, so protect CA keys (offline root, HSM, name constraints, few people with access).

If a *public CA you use* is distrusted: you have a deadline to replace the certificates, so keep inventory of which CA issued what, and keep automation CA-agnostic.

### Detection
- **Certificate Transparency (CT):** public CAs log certificates. Monitor logs for your domains (crt.sh, CT monitors) to spot mis-issuance.
- **CAA DNS records:** state which CAs may issue for your domain; compliant CAs must check it.
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
You own the private key and the renewal process. A cert that is perfect on day one still fails on day 90 if nothing renews it.

## Common mistakes
- Manual renewal with only a calendar reminder.
- Renewing the cert but not reloading the service.
- Reusing the same private key forever, or copying it across many hosts.
- Forgetting certificates embedded in config, secrets, or devices.

## Recap
- Key → CSR → CA validation → issuance → deploy → renew.
- Automate with ACME or an internal equivalent.
- Revocation is weak in practice; prefer short lifetimes and protect keys.
- If a key leaks, replace the key (not just the certificate), revoke, and check CT.
