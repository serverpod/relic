#!/bin/sh
# Writes the TLS test material: a CA, an intermediate it signs, and
# localhost leaves. The leaves cover the keys the server takes, an EC P-256
# key as PKCS#8 and as SEC 1, an RSA 2048 key and an Ed25519 key, and what
# it refuses, an encrypted key and an expired certificate. One leaf hangs
# off the intermediate, with the chain file holding both. The CA and the
# intermediate are valid for a century. Apple's verifier, which Dart uses
# on macOS, refuses a server certificate valid for more than 825 days, so
# the leaves expire after that and a rerun renews them. The CA and
# intermediate keys are thrown away, so a rerun replaces it all.
set -eu
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ca NAME OUT_CERT SIGNER_CERT SIGNER_KEY: a CA certificate for the key in
# $tmp/NAME_key.pem, self-signed when the signer is the key itself.
ca() {
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$tmp/$1_key.pem"
  if [ "$3" = self ]; then
    openssl req -new -x509 -key "$tmp/$1_key.pem" -out "$2" -days 36500 \
      -subj "/CN=relic_native test $1" \
      -addext "basicConstraints=critical,CA:TRUE" \
      -addext "keyUsage=critical,keyCertSign"
  else
    printf '%s\n' \
      "basicConstraints=critical,CA:TRUE" \
      "keyUsage=critical,keyCertSign" > "$tmp/$1.ext"
    openssl req -new -key "$tmp/$1_key.pem" -out "$tmp/$1.csr" \
      -subj "/CN=relic_native test $1"
    openssl x509 -req -in "$tmp/$1.csr" -CA "$3" -CAkey "$4" \
      -out "$2" -days 36500 -extfile "$tmp/$1.ext"
  fi
}

# leaf NAME KEY SIGNER_CERT SIGNER_KEY [x509 options]: NAME_cert.pem for
# localhost with the key in KEY, signed by the signer.
leaf() {
  name=$1 key=$2 signer_cert=$3 signer_key=$4
  shift 4
  openssl req -new -key "$key" -out "$tmp/$name.csr" -subj "/CN=localhost"
  printf '%s\n' \
    "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1" \
    "basicConstraints=critical,CA:FALSE" \
    "extendedKeyUsage=serverAuth" > "$tmp/$name.ext"
  openssl x509 -req -in "$tmp/$name.csr" -CA "$signer_cert" -CAkey "$signer_key" \
    -out "${name}_cert.pem" -days 825 -extfile "$tmp/$name.ext" "$@"
}

ca ca ca_cert.pem self self
ca intermediate "$tmp/intermediate_cert.pem" ca_cert.pem "$tmp/ca_key.pem"

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out localhost_key.pem
leaf localhost localhost_key.pem ca_cert.pem "$tmp/ca_key.pem"
openssl ec -in localhost_key.pem -out localhost_sec1_key.pem
openssl pkcs8 -topk8 -v2 aes-256-cbc -passout pass:relic \
  -in localhost_key.pem -out localhost_encrypted_key.pem

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out localhost_rsa_key.pem
leaf localhost_rsa localhost_rsa_key.pem ca_cert.pem "$tmp/ca_key.pem"

openssl genpkey -algorithm Ed25519 -out localhost_ed25519_key.pem
leaf localhost_ed25519 localhost_ed25519_key.pem ca_cert.pem "$tmp/ca_key.pem"

leaf localhost_expired localhost_key.pem ca_cert.pem "$tmp/ca_key.pem" \
  -not_before 20200101000000Z -not_after 20200102000000Z

leaf localhost_chain localhost_key.pem "$tmp/intermediate_cert.pem" "$tmp/intermediate_key.pem"
cat "$tmp/intermediate_cert.pem" >> localhost_chain_cert.pem
