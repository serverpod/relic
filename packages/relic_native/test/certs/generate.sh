#!/bin/sh
# Writes the TLS test material: a CA, and localhost leaves it signs with an
# EC P-256 key and an RSA 2048 key. The CA is valid for a century. Apple's
# verifier, which Dart uses on macOS, refuses a server certificate valid
# for more than 825 days, so the leaves expire after that and a rerun
# renews them. The CA key is thrown away, so a rerun replaces it all.
set -eu
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$tmp/ca_key.pem"
openssl req -new -x509 -key "$tmp/ca_key.pem" -out ca_cert.pem -days 36500 \
  -subj "/CN=relic_native test CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign"

leaf() {
  openssl req -new -key "$1_key.pem" -out "$tmp/$1.csr" -subj "/CN=localhost"
  printf '%s\n' \
    "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1" \
    "basicConstraints=critical,CA:FALSE" \
    "extendedKeyUsage=serverAuth" > "$tmp/$1.ext"
  openssl x509 -req -in "$tmp/$1.csr" -CA ca_cert.pem -CAkey "$tmp/ca_key.pem" \
    -CAcreateserial -out "$1_cert.pem" -days 825 -extfile "$tmp/$1.ext"
}

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out localhost_key.pem
leaf localhost
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out localhost_rsa_key.pem
leaf localhost_rsa
rm -f ca_cert.srl
