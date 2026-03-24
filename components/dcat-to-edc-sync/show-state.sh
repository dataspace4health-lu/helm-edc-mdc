#!/usr/bin/env bash
# show-state.sh – Print the current sync state from the PVC.
set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"
RELEASE="${RELEASE:-dcat-to-edc-sync}"

OVERRIDES=$(kubectl get cronjob "${RELEASE}" -n "${NAMESPACE}" -o json \
  | python3 -c "
import json, sys
cj = json.load(sys.stdin)
template = cj['spec']['jobTemplate']['spec']['template']['spec']
template['containers'][0]['command'] = ['python', 'sync_job.py', '--show-state']
print(json.dumps({'spec': template}))
")

kubectl run sync-state-reader \
  --rm -i \
  --restart=Never \
  --namespace "${NAMESPACE}" \
  --image="$(kubectl get cronjob "${RELEASE}" -n "${NAMESPACE}" \
      -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')" \
  --overrides="${OVERRIDES}" 2>/dev/null
