subst_manifest() {
  local file="$1"
  [ -e "$file" ] || return
  envsubst <"$file"
}

apply_k8s_file() {
  local file="$1"
  local cluster_name="${2:-$CLUSTER_NAME}"
  if [[ "$file" == *"crd"* ]]; then
    echo "Applying CRD with server-side apply: $file (Cluster: $cluster_name)"
    subst_manifest "$file" | kubectl apply --context="kind-${cluster_name}" --server-side -f -
  else
    subst_manifest "$file" | kubectl apply --context="kind-${cluster_name}" -f -
  fi
}

apply_with_subst() {
  local target="$1"
  local cluster_name="${2:-$CLUSTER_NAME}"
  if [ -d "$target" ]; then
    for file in "$target"*.yaml; do
      if [[ "$file" == *".conditional.yaml" ]]; then
        continue
      fi
      apply_k8s_file "$file" "$cluster_name"
    done
  elif [ -f "$target" ]; then
    apply_k8s_file "$target" "$cluster_name"
  else
    echo "Warning: '$target' is not a valid file or directory"
  fi
}

create_tls_secret() {
  local secret_name="$1"
  local namespace="$2"
  local cert="$3"
  local key="$4"
  local cluster_name="${5:-$MEDIA_CLUSTER_NAME}"

  kubectl create secret tls "$secret_name" \
    --namespace "$namespace" \
    --cert="$cert" \
    --key="$key" \
    --dry-run=client -o yaml | kubectl apply --context="kind-${cluster_name}" -f -
}

build_and_load_image() {
  local image_name="$1"
  local dockerfile_path="$2"
  local build_context="$3"
  local cluster_name="$4"

  if ! docker inspect --type=image "$image_name" >/dev/null 2>&1; then
    echo "Building ${image_name}..."
    docker build -t "$image_name" -f "$dockerfile_path" "$build_context" >/dev/null
  else
    echo "Image ${image_name} already exists in Docker, skipping build."
  fi

  echo "Loading ${image_name} into Kind..."
  kind load docker-image "$image_name" --name "$cluster_name" >/dev/null
}
