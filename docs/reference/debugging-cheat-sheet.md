---
title: Debugging cheat sheet
parent: Learn path
nav_order: 8
---

# Debugging cheat sheet

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
5. **Check purpose and usage**  
   Confirm Key Usage / EKU match (`serverAuth` for server, `clientAuth` for mTLS clients).
6. **Confirm the runtime trust store path**  
   Identify whether the failing client uses OS trust, Java truststore, `certifi`, or a container-specific store.

## Useful commands

```sh
# What does the server present? Does it verify?
openssl s_client -connect host:443 -servername host -showcerts </dev/null

# Inspect a cert
openssl x509 -in cert.pem -noout -text

# Validate a chain locally
openssl verify -CAfile root.pem -untrusted intermediate.pem leaf.pem

# Does the key match the cert? (compare derived public-key fingerprints)
openssl x509 -in cert.pem -noout -pubkey | openssl sha256
openssl pkey -in key.pem -pubout | openssl sha256

# Check expiry soon (exit 1 if it expires within 30 days)
openssl x509 -in cert.pem -noout -checkend 2592000

# curl with a specific CA, and client cert
curl --cacert root.pem --cert client.pem --key client.key https://svc.internal
```

## Common errors

| Error | Likely cause |
|---|---|
| `unable to get local issuer certificate` | Missing intermediate or untrusted root |
| `certificate has expired` | Expiry, or wrong system clock |
| `hostname mismatch` / `no alternative names` | Name not in SAN |
| `unsupported certificate purpose` | EKU mismatch |
| `bad certificate` (from server) | Client cert rejected in mTLS |
| `self signed certificate` | Private/self-signed cert not in trust store |
