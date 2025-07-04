#!/bin/sh
set -e
cd /certs

# Wait until certs are present (mounted by docker-compose)
while [ ! -f ca.crt ]; do
  echo "[OCSP] Waiting for certificates in /certs ..."
  sleep 1
done

echo "[OCSP] Starting OpenSSL OCSP responder on port 8080"
# -ignore_err allows startup even if index.txt is empty
aexec() { echo "+ $*"; exec "$@"; }
aexec openssl ocsp \
  -index index.txt \
  -port 8080 \
  -rsigner ocsp.crt \
  -rkey ocsp.key \
  -CA ca.crt \
  -ignore_err -text