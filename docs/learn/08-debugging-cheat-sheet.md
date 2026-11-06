---
title: 8. Debugging cheat sheet
parent: Learn path
nav_order: 8
---

# 8. Debugging Cheat Sheet

## Quick certificate triage flow

When a TLS or certificate check fails, run this order before changing code:

1. **Capture what the server actually presents**  
   `openssl s_client -connect host:443 -servername host -showcerts </dev/null`
2. **Check name match (SAN vs requested host)**  
   Verify the DNS/IP you connected to is present in SAN and of the correct SAN type.
3. **Check time validity and system clock**  
   Confirm `notBefore` / `notAfter` and check for clock skew.
4. **Verify the chain with explicit trust inputs**  
   `openssl verify -CAfile root.pem -untrusted intermediate.pem leaf.pem`  
   This checks the chain only. Add `-verify_hostname host` (and `-purpose sslserver`) to also check the name and purpose.
5. **Check purpose and usage**  
   Confirm Key Usage / EKU match (`serverAuth` for server, `clientAuth` for mTLS clients).  
   `openssl verify ... -purpose sslserver leaf.pem` (or `sslclient`) checks this.
6. **Confirm the runtime trust store path**  
   Identify whether the failing client uses OS trust, Java truststore, `certifi`, or a container-specific store.

## Useful commands

```sh
# What does the server present? Does it verify?
openssl s_client -connect host:443 -servername host -showcerts </dev/null

# Inspect a cert
openssl x509 -in cert.pem -noout -text

# Validate a chain locally (add -verify_hostname to also check the name)
openssl verify -CAfile root.pem -untrusted intermediate.pem -verify_hostname svc.example.com leaf.pem

# Does the key match the cert? (compare derived public-key fingerprints)
openssl x509 -in cert.pem -noout -pubkey | openssl sha256
openssl pkey -in key.pem -pubout | openssl sha256

# Check expiry soon (exit 1 if it expires within 30 days)
openssl x509 -in cert.pem -noout -checkend 2592000

# curl with a specific CA, and client cert
curl --cacert root.pem --cert client.pem --key client.key https://svc.internal
```

## Common errors

Wording differs between tools and languages (for example Go says `x509: certificate signed by unknown authority`, Java says `PKIX path building failed`), but the underlying causes are the same. You can reproduce most of these in the [hands-on lab](11-hands-on-lab.md#step-6-break-it-on-purpose).

| Error | Likely cause | What to do |
|---|---|---|
| `unable to get local issuer certificate` (Go: `certificate signed by unknown authority`, Java: `PKIX path building failed`) | **Either** the server did not send its intermediate, **or** the client does not trust the root | Run `openssl s_client -showcerts`. If only the leaf is listed, fix the server to send the full chain. If the chain is complete, add the right root to *this runtime's* trust store ([chapter 6](06-where-you-use-it.md#trust-a-private-ca-in-your-runtime)) |
| `certificate has expired` | Certificate expired, or the client clock is wrong | Check `notAfter` with `openssl x509 -noout -dates`; check the client's time and NTP. Renew, deploy, and reload |
| `hostname mismatch` / `no alternative certificate subject name matches` | The name you connected to is not in the SAN | Compare the URL host with the SAN. Connect using a name in the SAN, or reissue with the right DNS/IP SAN |
| `unsuitable certificate purpose` (`unsupported certificate purpose` before OpenSSL 3) | EKU does not allow this use | Reissue with `serverAuth` for servers or `clientAuth` for mTLS clients |
| `self-signed certificate` (`self signed certificate` before OpenSSL 3) | The leaf is self-signed and not in the trust store | Trust that specific cert for this client, or better, issue it from a private CA |
| `self-signed certificate in certificate chain` | The chain ends in a root the client does not trust; often a corporate TLS-inspection proxy or a private CA | Identify the root (`s_client` issuer lines). If it is legitimate, add it to the runtime's trust store; otherwise treat it as a possible MITM |
| `bad certificate` (alert from server) | mTLS: server rejected the client cert (for example expired or invalid) | Check the server's logs for the reason; inspect the client cert's dates and chain |
| `unsupported certificate` (alert from server) | mTLS: client cert is valid but not for this purpose, typically missing `clientAuth` EKU | Issue a client certificate with `clientAuth`; do not reuse a server certificate |
| `unknown ca` (alert from server) | mTLS: server does not trust the CA that issued the client cert | Add the client CA to the server's client trust store, or use a cert from the expected CA |
| `certificate required` (alert from server) | TLS 1.3 mTLS: the client sent no certificate | Configure the client cert and key (`--cert`/`--key`, `load_cert_chain`) |
| Error only in one environment (container, CI, one language) | Different trust store or clock | Compare which trust store each runtime uses and the system time |
