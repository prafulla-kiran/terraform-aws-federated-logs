#!/usr/bin/env bash
set -euo pipefail

#
# Registers (or updates) a Data Processing Entity via NerdGraph.
# Writes the entity ID + destroy-time metadata to STATE_FILE.
#
# Required env vars:
#   NR_ACCOUNT_ID, NR_USER_API_KEY, NR_ENDPOINT,
#   BASE_ROLE_ARN, FLEET_ID, AUTH_MODE, STATE_FILE
#

: "${NR_ACCOUNT_ID:?NR_ACCOUNT_ID is required}"
: "${NR_USER_API_KEY:?NR_USER_API_KEY is required}"
: "${NR_ENDPOINT:?NR_ENDPOINT is required}"
: "${BASE_ROLE_ARN:?BASE_ROLE_ARN is required}"
: "${FLEET_ID:?FLEET_ID is required}"
: "${AUTH_MODE:?AUTH_MODE is required}"
: "${STATE_FILE:?STATE_FILE is required}"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "ERROR: $cmd not found in PATH" >&2; exit 1; }
done

# NerdGraph mutation — adjust mutation name/fields to match your NGEP schema
MUTATION=$(cat <<EOF
mutation {
  federatedLogsDataProcessingEntityCreate(
    accountId: ${NR_ACCOUNT_ID}
    input: {
      baseRoleArn: "${BASE_ROLE_ARN}"
      fleetId: "${FLEET_ID}"
      authMode: ${AUTH_MODE}
    }
  ) {
    entity {
      id
    }
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

# Check for errors
ERRORS="$(echo "${RESP}" | jq -r '.data.federatedLogsDataProcessingEntityCreate.errors // [] | length')"
if [[ "${ERRORS}" != "0" ]]; then
  echo "ERROR: NerdGraph returned errors:" >&2
  echo "${RESP}" | jq -r '.data.federatedLogsDataProcessingEntityCreate.errors' >&2
  exit 1
fi

ENTITY_ID="$(echo "${RESP}" | jq -r '.data.federatedLogsDataProcessingEntityCreate.entity.id // empty')"
if [[ -z "${ENTITY_ID}" ]]; then
  echo "ERROR: No entity ID in response: ${RESP}" >&2
  exit 1
fi

# Persist entity ID (+ API key for destroy) to the state file
jq -nc \
  --arg entity_id "${ENTITY_ID}" \
  --arg nr_user_api_key "${NR_USER_API_KEY}" \
  '{entity_id: $entity_id, nr_user_api_key: $nr_user_api_key}' \
  > "${STATE_FILE}"

chmod 600 "${STATE_FILE}"

echo "SUCCESS: Registered data processing entity ${ENTITY_ID}"
