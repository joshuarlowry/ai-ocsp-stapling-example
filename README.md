# OCSP Stapling Demo

A real-world, end-to-end example that shows how **Online Certificate Status Protocol (OCSP) stapling** can be enabled in a modern micro-service stack.

> TL;DR: Run `docker compose up --build`, open https://localhost and inspect the TLS handshake – you will see the pre-fetched OCSP response (the *staple*) delivered by the proxy instead of an extra round-trip to the CA.

---

## Table of Contents
1. What is OCSP?
2. What is OCSP Stapling and why use it?
3. How OCSP Stapling works in this project
4. Architecture & Containers
5. Quick Start (docker compose)
6. Generating the demo PKI with OpenSSL
7. How to inspect the staple
8. Cleaning up
9. References

---

## 1. What is OCSP?
**OCSP** is an Internet PKI standard (RFC 6960) that allows clients to check whether an X.509 certificate has been revoked **online**. Instead of downloading a full Certificate Revocation List (CRL), the client sends a small HTTP request that contains the certificate serial number to an **OCSP Responder** operated by the Certificate Authority (CA). The responder answers with the certificate status: *good*, *revoked* or *unknown*.

Pros:
* Near real-time revocation information
* Lightweight compared to CRLs

Cons:
* Extra network round-trip on every handshake
* Adds latency to HTTPS connections
* Creates a privacy leak – the CA learns which sites a user visits

---

## 2. What is OCSP Stapling & why use it?
**OCSP Stapling** (RFC 6066, TLS extension `status_request`) moves the responsibility for querying the CA from the **client** to the **server**:

1. The server periodically fetches (and caches) its own OCSP response from the CA.
2. During the TLS handshake the server *staples* (attaches) this signed response to the `Certificate` message.
3. The client validates the staple using the CA's signature – no need to contact the OCSP Responder directly.

Benefits:
* 🏎  **Performance** – eliminates an extra round-trip, reducing TLS handshake latency by ~100-300 ms.
* 🔒  **Privacy** – the CA no longer sees which clients visit the site.
* 🌩  **Resilience** – clients can still validate your certificate even if the CA's OCSP endpoint is unreachable.

---

## 3. How OCSP Stapling works in this project
This repository provisions a tiny PKI, starts an **Apache HTTP Server** configured for OCSP stapling in front of a **FastAPI** application and serves a minimal JavaScript UI. An **OCSP Responder** container (based on an existing image) answers status requests for the demo CA.

The Apache proxy (TLS terminator) automatically retrieves the OCSP response with `mod_ssl` and caches it. When your browser connects, you can see the stapled response in DevTools or via `openssl s_client`.

---

## 4. Architecture & Containers

```
+-------------+       HTTPS (TLS+Staple)      +-----------+
|   Browser   |  <---------------------------- |  PROXIER  |
+-------------+                               +-----------+
                                                       |
                                                       |  HTTP
                                                       v
                                              +----------------+
                                              |     API        |
                                              | (FastAPI)      |
                                              +----------------+

+-----------------+            +-------------------+
|    CA & PKI     |  ----->    |  OCSP_Responder   |
|   (OpenSSL)     |  CRL/DB    | (RFC 6960 server) |
+-----------------+            +-------------------+
```

Container overview:

| Name | Base Image | Purpose |
|------|------------|---------|
| **UI** | `node:alpine` → `nginx:alpine` | Serves the static frontend (JS/HTML/CSS). |
| **API** | `python:3.12-slim` | FastAPI backend (echo service). |
| **PROXIER** | `httpd:2.4-alpine` | TLS termination, reverse proxy to API, OCSP stapling enabled. |
| **OCSP_Responder** | [`wheelybird/ocsp-responder`](https://hub.docker.com/r/wheelybird/ocsp-responder) | Answers OCSP requests for the demo CA. |

---

## 5. Quick Start
Prerequisites: Docker Desktop or Docker Engine 20+ & Docker Compose v2.

```bash
# clone and run
$ git clone https://github.com/your-org/ocsp-stapling-demo.git
$ cd ocsp-stapling-demo
$ docker compose up --build
```

Now visit **https://localhost** (self-signed CA, so add a security exception) – the page should load instantly.

---

## 6. Generating the demo PKI with OpenSSL (already scripted)
If you are curious, look at `pki/gen.sh` which:

1. Creates a root CA and issues a server certificate for `localhost`.
2. Generates an **OCSP Responder** certificate with the `OCSP Signing` EKU.
3. Exports the necessary files (`ca.crt`, `server.crt`, `server.key`, `ocsp.crt`, `ocsp.key`, `index.txt`, `serial`, etc.) that are mounted into the containers.

Feel free to tweak the script or rebuild the PKI:

```bash
$ ./pki/gen.sh && docker compose build proxier ocsp_responder
```

---

## 7. How to inspect the stapled response

### OpenSSL
```bash
$ openssl s_client -connect localhost:443 -servername localhost -status 2>/dev/null | grep -A 15 "OCSP Response Data"
```
You should see `OCSP Response Status: successful (0x0)`.

### Browser DevTools
1. Open **Network** tab → click the request → **Security** panel.
2. Look for *OCSP Response* = *Good*.

---

## 8. Cleaning up
```bash
$ docker compose down -v
```

---

## 9. References
* RFC 6960 – Online Certificate Status Protocol
* RFC 6066 – TLS Extensions (section 7 – OCSP stapling)
* [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
* [FastAPI](https://fastapi.tiangolo.com/)
* [Apache HTTP Server – OCSP Stapling How-To](https://httpd.apache.org/docs/2.4/howto/ssl.html#ocspstapling)

---

Feel free to open issues or pull requests – happy stapling! :tada:
