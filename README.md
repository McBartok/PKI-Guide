# PKI & Certificate Flow: A Developer Primer

A short, concept-first guide for developers and engineers who use certificates (HTTPS, mTLS, signing) and want to understand **how, why, and where** they work, not just which flags make the error go away.

## Core learn path (0-7)

0. [Crash course](docs/learn/00-crash-course.md): the whole picture in one sitting (new to this? start here; otherwise skip to 1)
1. [Cryptography foundations](docs/learn/01-crypto-foundations.md): security properties, hashing, symmetric/asymmetric, forward secrecy, algorithm choice
2. [Certificates and X.509](docs/learn/02-certificates-and-x509.md): what is inside a certificate and the file formats
3. [Trust and chains](docs/learn/03-trust-and-chains.md): CAs, trust stores, and path validation
4. [TLS and mTLS flow](docs/learn/04-tls-and-mtls-flow.md): where certificates are used in a handshake
5. [Certificate lifecycle](docs/learn/05-certificate-lifecycle.md): CSR, issuance, renewal, revocation, automation, key compromise and incident response
6. [Where you use it](docs/learn/06-where-you-use-it.md): real-world uses and deployment context
7. [Modern PKI and advanced topics](docs/learn/07-modern-pki-and-advanced-topics.md): crypto agility, post-quantum transition, lifecycle automation, cloud-native PKI, and CT/CAA monitoring

## Optional reference

- [Trust failures, pinning, and case studies](docs/reference/07-trust-failures-pinning-and-case-studies.md): deeper threat scenarios and incident analysis
- [Debugging cheat sheet](docs/reference/debugging-cheat-sheet.md): triage flow, commands, and common errors
- [Navigation and sidebar ordering](docs/reference/navigation-and-sidebar-ordering.md): `nav_order` and sidebar sequencing guidance
- [Glossary](docs/glossary.md): quick definitions for core PKI/TLS terms

## Conventions

- Snippets use `openssl` and Python (`cryptography` package). They illustrate concepts; they are not labs.
- Each chapter ends with a short recap.

## Prerequisites and scope

You should be comfortable with basic client/server networking and the command line. This guide focuses on how developers use certificates and TLS; it does not attempt to provide a complete PKI operator's manual, cryptographic proof, or production CA deployment guide.

For certificate troubleshooting, start with [trust and chains](docs/learn/03-trust-and-chains.md), then read [TLS and mTLS flow](docs/learn/04-tls-and-mtls-flow.md), and use the [debugging cheat sheet](docs/reference/debugging-cheat-sheet.md).

## Diagram generation (Mermaid to SVG)

The TLS flow diagrams are maintained as Mermaid source and compiled into SVG during CI:

- Source files: [docs/diagrams/](docs/diagrams/)
- Generated images: [docs/assets/img/](docs/assets/img/)
- Build steps are in [pages-deploy.yml](.github/workflows/pages-deploy.yml) and [docs-guardrails.yml](.github/workflows/docs-guardrails.yml)

When editing diagram content, update the `.mmd` files; workflows regenerate the `.svg` assets before site build.

## The whole idea in one paragraph

Public-key cryptography lets you prove you hold a private key without revealing it. A certificate binds a public key to an identity, and a Certificate Authority (CA) you already trust signs that binding. Verifying a certificate means checking a chain of signatures up to a trusted root, plus checks on name, validity, and purpose. Everything else (TLS, mTLS, ACME, revocation) is machinery around that idea.
