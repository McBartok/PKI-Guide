---
title: Home
nav_order: 1
---

# PKI & Certificate Flow

A short, concept-first guide for developers and engineers who use certificates (HTTPS, mTLS, signing) and want to understand **how, why, and where** they work.

## Start here

The main flow is the [Learn path](learn/index.md) (chapters 0-11).

## Choose a goal

### New to PKI
Start with the [Crash course](learn/00-crash-course.md), then read chapters [2](learn/02-certificates-and-x509.md), [3](learn/03-trust-and-chains.md), and [4](learn/04-tls-and-mtls-flow.md), and do the [Hands-on lab](learn/11-hands-on-lab.md). It takes about 30 minutes, and you'll see every concept working, and failing, on your own machine.

### Need to get something working
See the [practical recipes](learn/06-where-you-use-it.md#practical-recipes): trusting a private CA in each runtime, serving the full chain, HTTPS on localhost, and working behind a corporate proxy.

### Need to debug a certificate issue now
Read [Trust and chains](learn/03-trust-and-chains.md), [TLS and mTLS flow](learn/04-tls-and-mtls-flow.md), and the [Debugging cheat sheet](learn/08-debugging-cheat-sheet.md).

### Platform/security deep dive
Follow the full [Learn path](learn/index.md), then use the [Trust failures, pinning, and case studies appendix](learn/09-trust-failures-pinning-and-case-studies.md).

## Scope

This guide focuses on developer and engineering use of certificates and TLS. It is not a complete CA operations manual, cryptographic proof text, or production PKI deployment guide.
