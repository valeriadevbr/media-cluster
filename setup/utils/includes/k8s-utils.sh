# Outputs the file content with environment variables substituted
subst_manifest() {
  local file="$1"
  [ -e "$file" ] || return
  envsubst < "$file"
}

# Applies a single K8s manifest file with envsubst
apply_k8s_file() {
  local file="$1"
  subst_manifest "$file" | kubectl apply -f -
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
