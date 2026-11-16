############################################################
# kubernetes.zsh — Kubernetes / Helm helpers
# Loaded from ~/.zsh.d by the Stow-managed .zshrc.
############################################################

# Update kubeconfig for all clusters in a set of regions
updateKubeConfig() {
  local REGIONS=(us-east-1 us-east-2 ca-central-1 us-west-2)
  for r in "${REGIONS[@]}"; do
    echo "Adding EKS clusters in $r..."
    aws eks list-clusters --region "$r" | jq -r '.clusters[]' | while read -r cluster; do
      aws eks update-kubeconfig --region "$r" --name "$cluster" --alias "$cluster"
    done
  done
}

########## Kubernetes helpers ##########
clearNSFinalizers() {
  for ns in $(kubectl get ns --field-selector status.phase=Terminating -o jsonpath='{.items[*].metadata.name}'); do
    kubectl get ns "$ns" -ojson | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f -
    kubectl get ns "$ns" -ojson | jq '.metadata.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f -
  done
}

k8sDebug() {
  if [[ "$#" -lt 1 ]]; then
    echo "Usage: k8sDebug <debugType> [customImage] [-- customCommand...]"; echo "Types: busyBox, mongosh, curl, alpine, helloWorld, custom"; return
  fi
  local debugType="$1"; shift
  local podName image customCommand=() commandMode="none"
  if [[ "$debugType" == "custom" ]]; then
    [[ -z "$1" ]] && { echo "Provide an image for custom"; return 1; }
    image="$1"; podName="k8sdebug-custom"; shift
    if [[ "$1" == "--command-file" ]]; then shift; [[ -f "$1" ]] || { echo "file not found"; return 1; }
      read -r -a customCommand < "$1"; commandMode="file"
    elif [[ "$1" == "--command" ]]; then shift; [[ -n "$1" ]] || { echo "--command requires a string"; return 1; }
      if [[ -n "$ZSH_VERSION" ]]; then customCommand=("${(z)1}"); else IFS=$' \t\n' read -r -a customCommand <<< "$1"; fi; commandMode="string"
    elif [[ "$1" == "--" ]]; then shift; customCommand=("$@"); commandMode="array"
    fi
    if (( ${#customCommand[@]} )); then
      echo "▶ Running ephemeral container (mode: $commandMode)"; printf '  %q\n' "${customCommand[@]}"
      kubectl run "$podName" --rm -it --restart=Never --image="$image" -- "${customCommand[@]}"; return
    fi
  else
    case "$debugType" in
      busyBox) image="busybox"; podName="k8sdebug-busybox" ;;
      mongosh) image="rtsp/mongosh"; podName="k8sdebug-mongosh" ;;
      curl)    image="curlimages/curl"; podName="k8sdebug-curl" ;;
      alpine)  image="alpine"; podName="k8sdebug-alpine" ;;
      helloWorld) image="example.invalid/hello-world:latest"; podName="k8sdebug-helloworld" ;;
      *) echo "unknown debugType"; return 1 ;;
    esac
  fi
  kubectl get pod "$podName" >/dev/null 2>&1 && { echo "⚠️ Deleting existing pod $podName"; kubectl delete pod "$podName" --wait=false >/dev/null 2>&1; sleep 2; }
  echo "Launching pod $podName with image $image (shell mode)..."
  kubectl run "$podName" --image="$image" --restart=Never --command -- sleep 3600 --annotations="linkerd.io/inject=disabled" || { echo "Failed to create pod"; return 1; }
  echo "Waiting for pod..."
  if ! kubectl wait --for=condition=Ready pod/"$podName" --timeout=30s 2>/dev/null; then
    echo "❗ Pod not ready; try: k8sDebug custom $image -- <cmd>"; kubectl delete pod "$podName" --wait=false >/dev/null 2>&1; return 1
  fi
  local container=$(kubectl get pod "$podName" -o jsonpath='{.spec.containers[0].name}')
  ( sleep 300; kubectl delete pod "$podName" --wait=false >/dev/null 2>&1 ) &
  for shell in /bin/sh /bin/bash /bin/ash; do
    if kubectl exec "$podName" -c "$container" -- test -x "$shell" 2>/dev/null; then
      echo "✅ Launching shell: $shell"; kubectl exec -it "$podName" -c "$container" -- "$shell"; return
    fi
  done
  echo "❌ No shell found; try custom mode"
}

clearEvicted() { kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.reason!=null) | select(.status.reason | contains("Evicted")) | "kubectl delete pods \(.metadata.name) -n \(.metadata.namespace)"' | xargs -n1 bash -c; }
clearContainerStatusUnknown() { kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.containerStatuses != null) | select(.status.containerStatuses[].state.terminated.reason == "ContainerStatusUnknown") | "kubectl delete pod -n \(.metadata.namespace) \(.metadata.name)"' | xargs -n1 bash -c; }
clearError() { kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.containerStatuses != null) | select(.status.containerStatuses[].state.terminated.reason == "Error") | "kubectl delete pod -n \(.metadata.namespace) \(.metadata.name)"' | xargs -n1 bash -c; }

# Decode Helm release secrets
decodeHelmSecret() {
  local name="$1"
  [[ -z "$name" ]] && { echo "Missing secret name"; return 1; }
  if [[ "$name" == *"sh.helm.release"* ]]; then
    local json=$(kubectl get secret --ignore-not-found --all-namespaces -o json --field-selector "metadata.name=$name")
    local exists=$(echo "$json" | jq -r 'if (.items | length) > 0 then "true" else empty end')
    if [[ "$exists" == "true" ]]; then
      local data=$(echo "$json" | jq -r '.items[0].data.release' | base64 -d | base64 -d | gzip -d)
      data=$(echo "$data" | sed '/"notes":/,/},"chart":{/d')
      echo "Decoded Helm Release Data (cleaned):"; echo "$data"
      local keys=$(echo "$json" | jq '.items[0].data | keys[]' | grep -v '"release"')
      if [[ -n "$keys" ]]; then
        echo "Decoding additional base64-encoded fields..."
        for k in $keys; do k=${k//\"/}; echo "Field: $k"; echo "$json" | jq -r ".items[0].data.$k" | base64 -d 2>/dev/null || echo "(failed)"; done
      else
        echo "No additional fields"
      fi
    else
      echo "No such Helm secret"
    fi
  else
    echo "Not a Helm secret"
  fi
}

# Rollout all workloads
rolloutCluster() {
  kubectl get deployments --all-namespaces | tail +2 | awk '{ cmd=sprintf("kubectl rollout restart deployment -n %s %s", $1, $2) ; system(cmd) }'
  kubectl get daemonsets   --all-namespaces | tail +2 | awk '{ cmd=sprintf("kubectl rollout restart daemonset -n %s %s", $1, $2) ; system(cmd) }'
  kubectl get statefulsets --all-namespaces | tail +2 | awk '{ cmd=sprintf("kubectl rollout restart statefulset -n %s %s", $1, $2); system(cmd) }'
}
