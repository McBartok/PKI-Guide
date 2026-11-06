---
title: 11. Hands-on lab
parent: Learn path
nav_order: 11
---

# 11. Hands-on Lab: Build a PKI, Then Break It

**Goal:** build a three-level PKI (root → intermediate → server), serve HTTPS with it, and then cause the most common certificate errors on purpose so you recognise them in real life.

Time: about 30 minutes. Everything runs locally; nothing is installed system-wide.

## Before you start

You need:
- **OpenSSL 3.x** (`openssl version`). On macOS, `/usr/bin/openssl` is LibreSSL and lacks some options used here; use OpenSSL 3 from your package manager (for example Homebrew's `openssl@3`).
- **curl**.
- **Two terminals**: one runs the server, the other runs the client.

If your shell has `HTTPS_PROXY` set (common on corporate machines), add `--noproxy '*'` to the `curl` commands so they connect to your local server directly.

Create a scratch directory and stay in it in both terminals:
```sh
mkdir pki-lab && cd pki-lab
```

The private keys in this lab are created unencrypted (`-noenc`) for convenience. That is fine for a throwaway lab, never for real keys.

## Step 1: Create a root CA

```sh
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
  -keyout root.key -out root.pem -days 3650 -subj "/CN=Lab Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"
```

`-x509` makes a **self-signed** certificate: the subject and issuer are the same. This is your trust anchor ([chapter 3](03-trust-and-chains.md)). In real life the root key lives offline; here it is just a file.

## Step 2: Create an intermediate CA, signed by the root

```sh
cat > int.ext <<'EOF'
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
EOF

openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
  -keyout int.key -out int.csr -subj "/CN=Lab Intermediate CA"
openssl x509 -req -in int.csr -CA root.pem -CAkey root.key -days 1825 \
  -extfile int.ext -out int.pem
```

The first command creates a key and a CSR (the request). The second is the **root acting as a CA**: it signs the request and decides which extensions go in. `CA:TRUE,pathlen:0` means "may sign leaf certificates, but not further CAs".

## Step 3: Issue a server certificate, signed by the intermediate

```sh
cat > server.ext <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
EOF

openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
  -keyout server.key -out server.csr -subj "/CN=localhost"
openssl x509 -req -in server.csr -CA int.pem -CAkey int.key -days 30 \
  -extfile server.ext -out server.pem

cat server.pem int.pem > fullchain.pem
```

Note the SAN contains both a DNS name and an IP address, and the EKU is `serverAuth` ([chapter 2](02-certificates-and-x509.md)). `fullchain.pem` (leaf followed by intermediate) is what a real server should send.

## Step 4: Inspect and verify offline

```sh
openssl x509 -in server.pem -noout -subject -issuer -dates -ext subjectAltName,extendedKeyUsage
openssl verify -CAfile root.pem -untrusted int.pem server.pem
```

Expected: `server.pem: OK`. You just did path validation by hand: `root.pem` is the trust anchor, `int.pem` is an untrusted intermediate the verifier may use to build the path.

## Step 5: Serve HTTPS and connect

**Terminal 1 (server):**
```sh
openssl s_server -accept 8443 -cert server.pem -key server.key -cert_chain int.pem -www
```

**Terminal 2 (client):**
```sh
curl -sS -o /dev/null -w "%{http_code}\n" --cacert root.pem https://localhost:8443/
openssl s_client -connect localhost:8443 -servername localhost -CAfile root.pem </dev/null
```

`curl` should print `200`. In the `s_client` output, find the chain (`0 s:CN=localhost` / `1 s:CN=Lab Intermediate CA`) and `Verify return code: 0 (ok)`. [Chapter 4](04-tls-and-mtls-flow.md#follow-one-connection) walks through this output line by line.

## Step 6: Break it on purpose

Run each experiment, read the error, then compare it with the [debugging cheat sheet](08-debugging-cheat-sheet.md#common-errors). The exact wording varies between curl/OpenSSL builds and languages, but the cause is the same.

### 6a. The client does not trust the root
```sh
curl -sS https://localhost:8443/
```
```text
curl: (60) SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)
```
curl used the system trust store, which does not contain your lab root. Fix: give the client the right trust anchor (`--cacert root.pem`), **not** `-k`.

### 6b. The server does not send the intermediate
Stop the server (Ctrl-C) and restart it **without** `-cert_chain`:
```sh
openssl s_server -accept 8443 -cert server.pem -key server.key -www
```
```sh
curl -sS --cacert root.pem https://localhost:8443/
```
```text
curl: (60) SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)
```
**Same error as 6a, different cause.** The client trusts the root but cannot connect the leaf to it, because the intermediate is missing. Fix it on the server (send the full chain), not the client. Restart the server with `-cert_chain int.pem` before continuing.

### 6c. Wrong hostname
```sh
curl -sS --cacert root.pem --resolve wrong.test:8443:127.0.0.1 https://wrong.test:8443/
```
```text
curl: (60) SSL: no alternative certificate subject name matches target hostname 'wrong.test'
```
`--resolve` points `wrong.test` at your server. The chain is fine, but `wrong.test` is not in the SAN. Also try `https://127.0.0.1:8443/`: it works, because the certificate has an IP SAN.

### 6d. Expired certificate
Waiting 30 days is slow, so ask OpenSSL to validate as if it were 40 days from now:
```sh
openssl verify -CAfile root.pem -untrusted int.pem \
  -attime $(( $(date +%s) + 40*86400 )) server.pem
```
```text
error 10 at 0 depth lookup: certificate has expired
```
"Depth 0" is the leaf. A wrong system clock produces exactly the same error.

### 6e. Wrong purpose
Check the server certificate as if it were a client certificate:
```sh
openssl verify -CAfile root.pem -untrusted int.pem -purpose sslclient server.pem
```
```text
error 26 at 0 depth lookup: unsuitable certificate purpose
```
The EKU says `serverAuth` only.

### 6f. The server sends the root too, and the client does not trust it
```sh
cat server.pem int.pem root.pem > withroot.pem
openssl s_server -accept 8443 -cert server.pem -key server.key -cert_chain withroot.pem -www
```
```sh
curl -sS https://localhost:8443/
```
```text
curl: (60) SSL certificate OpenSSL verify result: self-signed certificate in certificate chain (19)
```
This is what you typically see behind a corporate TLS-inspection proxy or with an untrusted private CA: the chain ends in a root the client does not have. Sending the root does not make it trusted. Restart the server with `-cert_chain int.pem`.

## Step 7 (optional): Mutual TLS

Issue a client certificate from the same intermediate. Its identity is a URI SAN, as in SPIFFE ([chapter 7](07-modern-pki-and-advanced-topics.md)):
```sh
cat > client.ext <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=clientAuth
subjectAltName=URI:spiffe://lab.test/billing
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
EOF

openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc \
  -keyout client.key -out client.csr -subj "/CN=billing"
openssl x509 -req -in client.csr -CA int.pem -CAkey int.key -days 30 \
  -extfile client.ext -out client.pem
cat client.pem int.pem > client-fullchain.pem
```

Restart the server so it **requires** a client certificate that chains to your root:
```sh
openssl s_server -accept 8443 -cert server.pem -key server.key -cert_chain int.pem \
  -CAfile root.pem -Verify 1 -verify_return_error -www
```

Now try:

| Client command | Result |
|---|---|
| `curl -sS --cacert root.pem https://localhost:8443/` | `tlsv13 alert certificate required`: no client cert sent |
| `curl -sS --cacert root.pem --cert client-fullchain.pem --key client.key https://localhost:8443/` | Works |
| `curl -sS --cacert root.pem --cert fullchain.pem --key server.key https://localhost:8443/` | `alert unsupported certificate`: valid chain, but the EKU is `serverAuth`, not `clientAuth` |

Notice that the errors here are **alerts sent by the server**. The client only learns that it was rejected, not exactly why. When debugging mTLS, check the server's logs.

## Step 8: Clean up

```sh
cd .. && rm -rf pki-lab
```

Never add a lab root to your system trust store. If you did, remove it: anyone with `root.key` could impersonate any site to your machine ([chapter 9](09-trust-failures-pinning-and-case-studies.md#when-trust-breaks-deep-dive)).

## What you just learned
- A root is trusted because you configured it, not because of its signature.
- The server must send leaf + intermediate; the client must already have the root.
- The same error message can have a client-side or a server-side cause; work out which side is failing first.
- Name, time, and purpose are checked separately from the chain.
- In mTLS, the server's alert tells you *that* the client was rejected; the server's logs tell you *why*.
