---
title: 7. Modern PKI and advanced topics
parent: Learn path
nav_order: 7
---

# 7. Modern PKI and advanced topics

**Goal:** understand how modern PKI programs stay agile, automated, and cloud-native while reducing mis-issuance risk.

## Modern cryptographic agility and post-quantum PKI

Classical public-key systems (RSA, ECDSA, ECDH) are widely trusted today, but large-scale quantum computers would eventually threaten them.  
Practical migration is about **agility first**, not abrupt replacement.

Key points:
- Keep algorithm choices configurable in issuance and validation pipelines.
- Track support for emerging algorithms (for example ML-DSA and SLH-DSA) across CAs, HSMs, TLS stacks, and client platforms.
- Prefer staged rollouts (pilot, dual-path, baseline) over big-bang migrations.
- Expect **hybrid deployments** (classical + post-quantum) during transition periods.

Suggested migration checklist:
1. Inventory where RSA/ECDSA keys and signatures are used.
2. Verify platform/library support for post-quantum and hybrid modes.
3. Test interoperability per client/runtime version.
4. Define rollback paths and policy gates before production rollout.

## Automated lifecycle management (ACME and EST)

Manual CSR generation and one-off renewals do not scale. Modern PKI operations should prefer protocol-driven automation:
- **ACME** (for example Let's Encrypt, Smallstep): issuance and renewal for internet-facing and many internal use cases.
- **EST** (Enrollment over Secure Transport): common in enterprise and device environments where enrollment and policy integration are required.

Operational guidance:
- Treat certificates like short-lived infrastructure artifacts.
- Automate issuance, renewal, deployment, and service reloads.
- Alert on renewal failures, not just expiry dates.
- Reissue on key rotation events automatically.

Minimal automation loop:
```text
discover identity -> request/enroll cert -> deploy cert+key -> reload service
-> verify handshake -> monitor expiry and renewal success -> rotate keys on policy/incident
```

## Service mesh and cloud-native PKI

In cloud-native systems, PKI is often continuous and workload-driven:
- **SPIFFE/SPIRE**: workload identity and automated X.509 SVID issuance.
- **cert-manager** (Kubernetes): declarative certificate lifecycle for ingress/services/workloads.
- **HashiCorp Vault PKI**: central CA policy, dynamic certificate issuance, and controlled key/cert TTLs.

Common pattern:
- Issue short-lived workload certificates.
- Enforce mTLS between services by default.
- Bind identity to workload metadata (namespace/service account/trust domain).
- Rotate certificates frequently with zero-downtime renewals.

## Certificate Transparency (CT) logs and CAA monitoring

CT increases visibility into public certificate issuance:
- Public CAs submit issued certificates to append-only CT logs.
- Domain owners monitor CT to detect unexpected or fraudulent issuance.
- Alerts from CT should feed incident response and reissuance playbooks.

CAA DNS records narrow issuance authorization:
- Publish which CAs may issue for your domain.
- Public CAs should honor CAA before issuance.
- CAA does not replace CT; use both.

Example CAA records:
```dns
example.com. 3600 IN CAA 0 issue "letsencrypt.org"
example.com. 3600 IN CAA 0 iodef "mailto:security@example.com"
```

## Recap
- Build crypto agility now so algorithm transitions are operationally safe.
- Prefer ACME/EST automation over manual CSR workflows.
- Use cloud-native identity systems to issue short-lived mTLS certificates at scale.
- Combine CT monitoring and CAA policy to reduce and detect mis-issuance risk.
