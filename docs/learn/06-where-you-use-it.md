---
title: 6. Where you use it
parent: Learn path
nav_order: 6
---

# 6. Where You Use It

**Goal:** map the concepts to real situations, and have a debugging toolkit ready.

## Where certificates show up

| Use | Certificate role | Notes |
|---|---|---|
| **HTTPS / public web** | Server identity, public CA | Automate with ACME. |
| **Internal services / mTLS** | Server and client identity, private CA | Service-to-service auth; often via a service mesh (Istio, Linkerd) that issues short-lived workload certs. |
| **Kubernetes** | API server, kubelets, ingress, workloads | cert-manager automates issuance and renewal. |
| **Code and artifact signing** | Binds a signature to a publisher | EKU `codeSigning`; timestamps keep signatures valid after cert expiry. |
| **Email (S/MIME)** | Sign and encrypt mail | Per-user certificates. |
| **Device / IoT identity** | Per-device client cert | Provisioned at manufacture or enrolment. |
| **VPN / Wi-Fi (802.1X)** | Client or server authentication | Often a private CA. |
| **Databases, brokers** | Encrypted transport and client auth | Same TLS/mTLS model. |

### Certificates vs. other credentials
- **API keys / passwords**: shared secrets that travel to the server. Certificates prove key possession without sending the secret.
- **JWTs**: signed tokens, usually verified with a public key fetched from a JWKS endpoint. Same signature idea, but no chain or CA unless you add one. Often combined with TLS.
- **SSH**: public keys with trust by explicit authorisation (or SSH CAs), not X.509.

### Public or private CA?
- Public clients you do not control: public CA.
- Systems you control end to end: private CA, with a clear plan to distribute and rotate its root.

## Pitfalls checklist
(Consequences and incident examples: [When trust breaks](09-trust-failures-pinning-and-case-studies.md#when-trust-breaks-deep-dive); response steps: [Compromise and incident response](05-certificate-lifecycle.md#compromise-and-incident-response).)
- Verification disabled "just for now".
- Name only in CN, no SAN.
- Intermediate not served.
- Expired cert or CA, with no monitoring.
- Wrong EKU (serverAuth vs clientAuth).
- Clock skew on devices or containers.
- Private key in git, images, or logs.
- Different trust stores across runtimes (OS, Java, Python, container base image).

## Troubleshooting and reference pages

- Use the [Debugging cheat sheet](08-debugging-cheat-sheet.md) for the step-by-step triage flow, OpenSSL/curl commands, and common error mapping.
- Use the [Glossary](10-glossary.md) for quick term lookups.

## Recap
- The same model (bound key, chain to a trusted anchor, checks on name, time, purpose) underlies every use.
- Choose the CA type by who your clients are; automate the lifecycle.
- When debugging, find out which side fails and which check it is.
