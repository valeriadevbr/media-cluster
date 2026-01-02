#!/bin/bash

generate_local_cert() {
  local host="$1"
  local ca_crt="$2"
  local ca_key="$3"
  local san_cnf="$4"
  local out_dir="$5"

  local filename="cert"
  local csr_path="${out_dir}/${filename}.csr"
  local key_path="${out_dir}/${filename}.key"
  local crt_path="${out_dir}/${filename}.crt"
  local pfx_path="${out_dir}/${filename}.pfx"
  local pem_path="${out_dir}/${filename}.pem"

  # Gera chave e CSR
  openssl req -new -newkey rsa:2048 -nodes \
    -keyout "$key_path" \
    -out "$csr_path" \
    -config "$san_cnf"

  # Assinar com a CA
  openssl x509 -req \
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

  # Converte o certificado e a chave para o formato PEM
  cat "$crt_path" "$key_path" >"$pem_path"

  # Limpa arquivos temporários
  rm "$csr_path"
}
