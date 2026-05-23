import json, urllib.request, os, sys

endpoint     = os.environ['NR_ENDPOINT']
nr_api_key   = os.environ['NEW_RELIC_API_KEY']
if not nr_api_key:
    print("Error: NEW_RELIC_API_KEY environment variable is not set", file=sys.stderr)
    sys.exit(1)
role_arn     = os.environ['ROLE_ARN']
name         = os.environ['ENTITY_NAME']
org_id       = os.environ['NR_ORG_ID']
setup_name   = os.environ['SETUP_NAME']


def call_graphql(query, variables=None):
    payload = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(endpoint, data=payload, headers={
        "Content-Type": "application/json",
        "API-Key": nr_api_key,
        "X-Query-Source-Capability-Id": "ADD_DATA"
    })
    try:
        return json.loads(urllib.request.urlopen(req).read())
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print("HTTP %d %s\nResponse: %s" % (e.code, e.reason, body), file=sys.stderr)
        sys.exit(1)

# Create the AWS Connection Entity that wraps the per-setup reader role —
# this is what NR query workers assume to read federated logs from S3.
# Mirrors data_processing/scripts/create_aws_connection.py but tagged with
# `federated_logs_setup` (per-setup) and `purpose=query` so a sibling fetch
# script can find it again later.
create_mutation = """
mutation($input: EntityManagementAwsConnectionEntityCreateInput!) {
  entityManagementCreateAwsConnection(awsConnectionEntity: $input) {
    entity { id }
  }
}
"""

create_variables = {
    "input": {
        "name": name,
        "credential": {"assumeRole": {"roleArn": role_arn}},
        "scope": {"id": org_id, "type": "ORGANIZATION"},
        "tags": [
            {"key": "federated_logs_setup", "values": [setup_name]},
            {"key": "purpose",              "values": ["query"]},
        ],
    }
}

resp = call_graphql(create_mutation, create_variables)

if "errors" in resp:
    errors = resp["errors"]
    if any(e.get("extensions", {}).get("errorClass") == "ENTITY_UNIQUE_CONSTRAINT_VIOLATION" for e in errors):
        print("Query AWS Connection Entity already exists for setup %s. Nothing to do." % setup_name)
        sys.exit(0)
    print("GraphQL errors (create entity): " + json.dumps(errors, indent=2), file=sys.stderr)
    sys.exit(1)

entity_id = resp['data']['entityManagementCreateAwsConnection']['entity']['id']
print("Created Query AWS Connection Entity: " + entity_id)
