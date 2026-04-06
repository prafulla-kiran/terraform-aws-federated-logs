#!/usr/bin/env bash
set -euo pipefail

#
# Deletes a Data Processing Entity via NerdGraph on terraform destroy.
# Reads entity_id and nr_user_api_key from STATE_FILE written by register_entity.sh.
#
# Required env vars:
#   NR_ACCOUNT_ID, NR_ENDPOINT, STATE_FILE
#

: "${NR_ACCOUNT_ID:?NR_ACCOUNT_ID is required}"
: "${NR_ENDPOINT:?NR_ENDPOINT is required}"
: "${STATE_FILE:?STATE_FILE is required}"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "$cmd not found" >&2; exit 1; }
done

if [[ ! -f "${STATE_FILE}" ]]; then
  echo "WARNING: State file ${STATE_FILE} not found — entity may already be deleted." >&2
  exit 0
fi

ENTITY_ID="$(jq -r '.entity_id // empty' "${STATE_FILE}")"
NR_USER_API_KEY="$(jq -r '.nr_user_api_key // empty' "${STATE_FILE}")"

if [[ -z "${ENTITY_ID}" ]]; then
  echo "WARNING: No entity_id in state file — nothing to delete." >&2
  exit 0
fi

if [[ -z "${NR_USER_API_KEY}" ]]; then
  echo "ERROR: No nr_user_api_key in state file — cannot authenticate." >&2
  exit 1
fi

MUTATION=$(cat <<EOF
mutation {
  federatedLogsDataProcessingEntityDelete(
    accountId: ${NR_ACCOUNT_ID}
    entityId: "${ENTITY_ID}"
  ) {
    success
    errors {
      message
      type
    }
  }
}
EOF
)

RESP="$(curl -sS -X POST "${NR_ENDPOINT}" \
  -H "Content-Type: application/json" \
  -H "API-Key: ${NR_USER_API_KEY}" \
  --data "$(jq -nc --arg q "${MUTATION}" '{query:$q}')")"

SUCCESS="$(echo "${RESP}" | jq -r '.data.federatedLogsDataProcessingEntityDelete.success // false')"
if [[ "${SUCCESS}" == "true" ]]; then
  echo "SUCCESS: Entity ${ENTITY_ID} deleted."
  rm -f "${STATE_FILE}"
else
  echo "WARNING: Entity deletion may have failed: ${RESP}" >&2
fi
