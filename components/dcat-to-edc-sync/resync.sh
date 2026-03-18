#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# resync.sh – Force re-sync of a single MDC dataset into EDC.
#
# Usage:
#   ./resync.sh <mdc_dataset_id>
#   NAMESPACE=my-ns ./resync.sh 42
#
# The script auto-discovers the image, env vars, volumes, and secrets from
# the running CronJob – no manual configuration required.
# ---------------------------------------------------------------------------
set -euo pipefail

DATASET_ID="${1:?Usage: resync.sh <mdc_dataset_id>   (MDC integer ID, e.g. 1)}"
NAMESPACE="${NAMESPACE:-default}"
RELEASE="${RELEASE:-dcat-to-edc-sync}"
JOB_NAME="dcat-resync-${DATASET_ID}-$(date +%s)"

echo "▶ Re-syncing MDC dataset ${DATASET_ID} in namespace '${NAMESPACE}' ..."

# Build the pod spec by reading the CronJob (env vars, volumes, secrets are
# already configured there) and overriding only the container command.
CRONJOB_JSON=$(kubectl get cronjob "${RELEASE}" -n "${NAMESPACE}" -o json)
OVERRIDES=$(echo "${CRONJOB_JSON}" | python3 -c "
import json, sys
dataset_id = '${DATASET_ID}'
cj = json.load(sys.stdin)
template = cj['spec']['jobTemplate']['spec']['template']['spec']
# Override only the command; everything else (env, volumes, secrets) stays
template['containers'][0]['command'] = ['python', 'sync_job.py', '--resync-dataset', dataset_id]
print(json.dumps({'spec': template}))
")

kubectl run "${JOB_NAME}" \
  --rm -i \
  --restart=Never \
  --namespace "${NAMESPACE}" \
  --image="$(kubectl get cronjob "${RELEASE}" -n "${NAMESPACE}" \
      -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')" \
  --overrides="${OVERRIDES}"

echo "✔ Re-sync of dataset ${DATASET_ID} complete."
