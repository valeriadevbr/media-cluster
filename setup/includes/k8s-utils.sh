subst_manifest() {
  local file="$1"
  [ -e "$file" ] || return
  envsubst <"$file"
}

apply_k8s_file() {
  local file="$1"
  local k8s_context="${2:-$K8S_CONTEXT}"
  if [[ "$file" == *"crd"* ]]; then
    echo "Applying CRD with server-side apply: $file (Context: $k8s_context)"
    subst_manifest "$file" | kubectl apply --context="$k8s_context" --server-side -f -
  else
    subst_manifest "$file" | kubectl apply --context="$k8s_context" -f -
  fi
}

apply_with_subst() {
  local target="$1"
  local k8s_context="${2:-$K8S_CONTEXT}"
  if [ -d "$target" ]; then
    for file in "$target"*.yaml; do
      if [[ "$file" == *".conditional.yaml" ]]; then
        continue
      fi
      apply_k8s_file "$file" "$k8s_context"
    done
  elif [ -f "$target" ]; then
    apply_k8s_file "$target" "$k8s_context"
  else
    echo "Warning: '$target' is not a valid file or directory"
  fi
}

create_tls_secret() {
  local secret_name="$1"
  local namespace="$2"
  local cert="$3"
  local key="$4"
  local k8s_context="${5:-$K8S_CONTEXT}"

  kubectl create secret tls "$secret_name" \
    --namespace "$namespace" \
    --cert="$cert" \
    --key="$key" \
    --dry-run=client -o yaml | kubectl apply --context="$k8s_context" -f -
}
