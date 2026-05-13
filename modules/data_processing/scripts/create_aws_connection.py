import json, urllib.request, os, sys

endpoint          = os.environ['NR_ENDPOINT']
api_key           = os.environ['NR_API_KEY']
role_arn          = os.environ['ROLE_ARN']
name              = os.environ['ENTITY_NAME']
org_id            = os.environ['NR_ORG_ID']
fleet_entity_guid = os.environ['FLEET_ENTITY_GUID']


def call_graphql(query):
    payload = json.dumps({"query": query}).encode()
    req = urllib.request.Request(endpoint, data=payload, headers={
        "Content-Type": "application/json",
        "API-Key": api_key,
        "X-Query-Source-Capability-Id": "ADD_DATA"
    })
    try:
        return json.loads(urllib.request.urlopen(req).read())
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print("HTTP %d %s\nResponse: %s" % (e.code, e.reason, body), file=sys.stderr)
        sys.exit(1)


# Step 1: Create AWS Connection Entity
create_mutation = """
mutation {
  entityManagementCreateAwsConnection(
    awsConnectionEntity: {
      name: "%s",
      credential: {assumeRole: {roleArn: "%s"}},
      scope: {id: "%s", type: ORGANIZATION},
      tags: [{key: "fleet_entity_guid", values: ["%s"]}]
    }
  ) {
    entity { id }
  }
}
""" % (name, role_arn, org_id, fleet_entity_guid)

resp = call_graphql(create_mutation)

if "errors" in resp:
    errors = resp["errors"]
    if any(e.get("extensions", {}).get("errorClass") == "ENTITY_UNIQUE_CONSTRAINT_VIOLATION" for e in errors):
        print("AWS Connection Entity already exists, relationship also already exists. Nothing to do.")
        sys.exit(0)
    print("GraphQL errors (create entity): " + json.dumps(errors, indent=2), file=sys.stderr)
    sys.exit(1)

entity_id = resp['data']['entityManagementCreateAwsConnection']['entity']['id']
print("Created AWS Connection Entity: " + entity_id)

# Step 2: Create HAS_FED_LOGS_BASE_ROLE relationship fleet_entity_guid -> aws_connection_entity
rel_mutation = """
mutation {
  entityManagementCreateRelationship(
    relationship: {
      source: {id: "%s", scope: ORGANIZATION}
      target: {id: "%s", scope: ORGANIZATION}
      type: "HAS_FED_LOGS_BASE_ROLE"
    }
  ) {
    relationship {
      type
      source { id }
      target { id }
    }
  }
}
""" % (fleet_entity_guid, entity_id)

resp = call_graphql(rel_mutation)
if "errors" in resp:
    print("GraphQL errors (create relationship): " + json.dumps(resp["errors"], indent=2), file=sys.stderr)
    sys.exit(1)

print("Created HAS_FED_LOGS_BASE_ROLE relationship: %s -> %s" % (fleet_entity_guid, entity_id))
