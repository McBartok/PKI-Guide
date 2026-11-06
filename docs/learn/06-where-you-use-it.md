---
title: 6. Where you use it
parent: Learn path
nav_order: 6
---

# 6. Where You Use It

**Goal:** map the concepts to real situations, and have practical recipes ready for the tasks developers hit most: trusting a private CA, serving the full chain, local HTTPS, and corporate proxies.

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

## Practical recipes

### Trust a private CA in your runtime
Most runtimes do **not** share one trust store. Adding a root to your OS store does not help a Python, Java, or Node app that brings its own bundle.

| Runtime | How to trust an extra root | Adds or replaces? |
|---|---|---|
| curl | `--cacert bundle.pem` or `CURL_CA_BUNDLE=bundle.pem` | Replaces |
| Python (`ssl`, `urllib`) | `ssl.create_default_context()` then `ctx.load_verify_locations("root.pem")`; or `SSL_CERT_FILE=bundle.pem` | `load_verify_locations` adds; `SSL_CERT_FILE` replaces |
| Python `requests` | `verify="bundle.pem"` or `REQUESTS_CA_BUNDLE=bundle.pem` | Replaces the `certifi` bundle |
| Node.js | `NODE_EXTRA_CA_CERTS=root.pem` (read once at startup), or `--use-system-ca` (recent versions) to use the OS store | Adds |
| Java | `keytool -importcert -alias internal-root -file root.pem -keystore truststore.p12 -storetype PKCS12`, then run with `-Djavax.net.ssl.trustStore=truststore.p12 -Djavax.net.ssl.trustStorePassword=...` | Replaces the default `cacerts`; import into a copy of `cacerts` to keep public roots |
| Go | In code: `x509.SystemCertPool()` then `AppendCertsFromPEM`. On Linux also `SSL_CERT_FILE` / `SSL_CERT_DIR`. On macOS and Windows Go uses the OS store | Pool adds; env vars replace |
| Debian, Ubuntu, Alpine (incl. containers) | Copy to `/usr/local/share/ca-certificates/internal-root.crt` (must end in `.crt`), run `update-ca-certificates`. Alpine needs the `ca-certificates` package first | Adds to the OS bundle |
| RHEL, Fedora | Copy to `/etc/pki/ca-trust/source/anchors/`, run `update-ca-trust` | Adds |
| macOS | `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain root.pem` | Adds |
| Windows | PowerShell as admin: `Import-Certificate -FilePath root.cer -CertStoreLocation Cert:\LocalMachine\Root` | Adds |

Where an option *replaces* the default store, public sites stop working unless your bundle also contains the public roots. Build one with `cat /etc/ssl/certs/ca-certificates.crt internal-root.pem > bundle.pem` (the system bundle path varies by OS), or scope the option to calls to the internal service only.

Minimal container images (`scratch`, distroless static, Alpine without `ca-certificates`) may have **no trust store at all**, which shows up as errors like `x509: certificate signed by unknown authority` for every HTTPS call.

### Serve the full chain
The most common server-side mistake is configuring only the leaf certificate. Point the server at a file containing the **leaf first, then the intermediates**. For nginx:

```nginx
server {
    listen 443 ssl;
    server_name api.example.com;

    ssl_certificate     /etc/ssl/api/fullchain.pem;   # leaf + intermediates, leaf first
    ssl_certificate_key /etc/ssl/api/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
}
```

ACME clients such as certbot write both `cert.pem` (leaf only) and `fullchain.pem`; use `fullchain.pem`. Apache 2.4.8+ also takes the full chain in `SSLCertificateFile`. Check the result with `openssl s_client`: the "Certificate chain" section should list more than one certificate ([chapter 4](04-tls-and-mtls-flow.md#follow-one-connection)).

### TLS versions
- **TLS 1.3** (2018): faster handshake, forward secrecy on every full handshake, legacy algorithms removed. Prefer it.
- **TLS 1.2**: still acceptable with ECDHE key exchange and AEAD ciphers.
- **TLS 1.0 and 1.1**: formally deprecated (RFC 8996). Disable them.

Set the minimum to TLS 1.2 and leave cipher selection to current library defaults unless you have a reason not to. For server configuration, the [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/) is a good starting point.

### HTTPS on localhost
- Browsers treat `http://localhost` as a secure context, so plain HTTP is often enough for local development.
- When you do need HTTPS locally (for example OAuth redirect rules or `Secure` cookies across services), use a local development CA. You can build one as in the [hands-on lab](11-hands-on-lab.md) and trust it only in the specific client (`--cacert`, `NODE_EXTRA_CA_CERTS`). Alternatively, a tool such as [mkcert](https://github.com/FiloSottile/mkcert) creates and installs one for you.
- A local CA's private key can mint certificates for **any** name your machine will trust. Keep it on that machine only, never share or commit it, and uninstall the root when you are done ([chapter 9](09-trust-failures-pinning-and-case-studies.md#when-trust-breaks-deep-dive)).
- Do not "solve" local HTTPS by disabling verification in code; that code tends to ship.

### Behind a corporate TLS-inspection proxy
**Symptom:** the browser works, but curl, pip, npm, Java, or Docker builds fail with `self-signed certificate in certificate chain` or `unable to get local issuer certificate`. In `openssl s_client`, the issuer is your company's proxy rather than a public CA.

**Cause:** the proxy decrypts and re-signs traffic with a corporate root. IT installed that root in the OS store, but your runtime uses its own bundle (`certifi`, Java `cacerts`, Node's built-in list, or a container image).

**Fix:** get the corporate root certificate from IT and add it to the runtime that fails (see the table above). Do not set `verify=False`, `NODE_TLS_REJECT_UNAUTHORIZED=0`, or `curl -k`.

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
- Use the [Hands-on lab](11-hands-on-lab.md) to reproduce common failures safely on your own machine.

## Recap
- The same model (bound key, chain to a trusted anchor, checks on name, time, purpose) underlies every use.
- Choose the CA type by who your clients are; automate the lifecycle.
- When debugging, find out which side fails and which check it is.
