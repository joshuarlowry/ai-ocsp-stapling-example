#!/usr/bin/env bash
# Regenerates the demo PKI used by the containers.
# Requires: openssl (command-line)
# Outputs all artifacts into pki/output/ so they can be volume-mounted.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/output"

# Fresh start
rm -rf "$OUT"
mkdir -p "$OUT"/{certs,private,newcerts}

touch "$OUT/index.txt"
echo 1000 > "$OUT/serial"

########################################
# 1. Root CA
########################################
openssl genrsa -out "$OUT/private/ca.key" 4096
openssl req -x509 -new -nodes -key "$OUT/private/ca.key" \
    -sha256 -days 3650 -subj "/CN=Demo Root CA" \
    -out "$OUT/certs/ca.crt"

########################################
# 2. OpenSSL CA configuration (for issuing server + OCSP certs)
########################################
cat > "$OUT/openssl.cnf" <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir             = $OUT
certs           = \$dir/certs
new_certs_dir   = \$dir/newcerts
database        = \$dir/index.txt
serial          = \$dir/serial
private_key     = \$dir/private/ca.key
certificate     = \$dir/certs/ca.crt
default_md      = sha256
policy          = policy_any
copy_extensions = copy

[ policy_any ]
commonName              = supplied
stateOrProvinceName     = optional
countryName             = optional
organizationName        = optional
organizationalUnitName  = optional
emailAddress            = optional

[ server_cert ]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
authorityInfoAccess = OCSP;URI:http://ocsp_responder:8080
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost

[ v3_ocsp ]
basicConstraints = CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = OCSPSigning
EOF

########################################
# 3. OCSP Responder certificate
########################################
openssl genrsa -out "$OUT/private/ocsp.key" 2048
openssl req -new -key "$OUT/private/ocsp.key" -subj "/CN=Demo OCSP" -out "$OUT/ocsp.csr"
openssl ca -batch -config "$OUT/openssl.cnf" -extensions v3_ocsp -days 365 -in "$OUT/ocsp.csr" -out "$OUT/certs/ocsp.crt"

########################################
# 4. Server certificate for localhost
########################################
openssl genrsa -out "$OUT/private/server.key" 2048
openssl req -new -key "$OUT/private/server.key" -subj "/CN=localhost" -out "$OUT/server.csr"
openssl ca -batch -config "$OUT/openssl.cnf" -extensions server_cert -days 365 -in "$OUT/server.csr" -out "$OUT/certs/server.crt"

########################################
# 5. Convenience copies at root of output dir (mounted by containers)
########################################
cp "$OUT/certs/ca.crt"     "$OUT/ca.crt"
cp "$OUT/certs/ocsp.crt"   "$OUT/ocsp.crt"
cp "$OUT/private/ocsp.key" "$OUT/ocsp.key"
cp "$OUT/certs/server.crt" "$OUT/server.crt"
cp "$OUT/private/server.key" "$OUT/server.key"

printf "\nPKI generated. Files located in %s\n" "$OUT"