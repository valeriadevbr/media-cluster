#!/bin/bash

generate_cert() {
  local host="$1"
  local ca_crt="$2"
  local ca_key="$3"
  local san_cnf="$4"
  local pfx_path="$5"

  local work_dir=$(dirname "$pfx_path")
  local csr_path="${work_dir}/${host}.csr"
  local key_path="${work_dir}/${host}.key"
  local crt_path="${work_dir}/${host}.crt"

  # Gera a chave privada
  openssl genrsa -out "$key_path" 2048

  # Gera o CSR usando a chave privada e o SAN config
  openssl req \
    -new \
    -subj "/CN=$host" \
    -key "$key_path" \
    -out "$csr_path"

  # Assina o certificado com a CA usando o CSR e o SAN config
  openssl x509 \
    -req \
    -sha256 \
    -CAcreateserial \
    -days 825 \
    -extensions req_ext \
    -in "$csr_path" \
    -CA "$ca_crt" \
    -CAkey "$ca_key" \
    -extfile "$san_cnf" \
    -out "$crt_path"

  # Converte o certificado e a chave para o formato PFX
  openssl pkcs12 \
    -export \
    -certfile "$ca_crt" \
    -inkey "$key_path" \
    -in "$crt_path" \
    -out "$pfx_path" \
    -password pass:

  # Limpa arquivos temporários
  rm "$csr_path"
}
