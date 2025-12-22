# Outputs the file content with environment variables substituted
subst_manifest() {
  local file="$1"
  [ -e "$file" ] || return
  envsubst <"$file"
}

# Applies a single K8s manifest file with envsubst
apply_k8s_file() {
  local file="$1"
  if [[ "$file" == *"crd"* ]]; then
     echo "Applying CRD with server-side apply: $file"
     subst_manifest "$file" | kubectl apply --server-side -f -
  else
     subst_manifest "$file" | kubectl apply -f -
  fi
}

apply_with_subst() {
  local target="$1"
  if [ -d "$target" ]; then
    for file in "$target"*.yaml; do
      apply_k8s_file "$file"
    done
  # Check if target is a file
  elif [ -f "$target" ]; then
    apply_k8s_file "$target"
  else
    echo "Warning: '$target' is not a valid file or directory"
  fi
}

create_tls_secret() {
  local secret_name="$1"
  local namespace="$2"
  local cert="$3"
  local key="$4"
  kubectl create secret tls "$secret_name" \
    --namespace "$namespace" \
    --cert="$cert" \
    --key="$key" \
    --dry-run=client -o yaml | kubectl apply -f -
}
