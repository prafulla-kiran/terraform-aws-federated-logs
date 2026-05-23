import json, os, time, urllib.request, sys


def call_graphql(endpoint, nr_api_key, query):
    payload = json.dumps({"query": query}).encode()
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


nr_api_key = os.environ['NEW_RELIC_API_KEY']
if not nr_api_key:
    print("Error: NEW_RELIC_API_KEY environment variable is not set", file=sys.stderr)
    sys.exit(1)

query = json.load(sys.stdin)
setup_name  = query["setup_name"]
nr_endpoint = query["nr_endpoint"]

# Search for the per-setup query AWS Connection entity (tagged
# `federated_logs_setup=<setup_name>` and `purpose=query` by
# create_query_aws_connection.py). The entity's `guid` is the connection_id
# consumed by `newrelic_federated_logs_setup.storage.query_connection_id`.
#
# NGEP entitySearch is eventually consistent — a freshly-created entity
# typically takes a few seconds (occasionally 30s+) to appear in tag-based
# search. The create runs immediately before this fetch via depends_on, so we
# poll with a bounded budget instead of failing on the first miss.
search_query = """
{
  actor {
    entitySearch(query: "domain = 'NGEP' AND type = 'AWS_CONNECTION' AND tags.`federated_logs_setup` = '%s' AND tags.`purpose` = 'query'") {
      results {
        entities {
          guid
        }
      }
    }
  }
}
""" % setup_name

max_attempts  = 24   # 24 × 5s = 120s budget
poll_interval = 5

for attempt in range(1, max_attempts + 1):
    resp = call_graphql(nr_endpoint, nr_api_key, search_query)
    if "errors" in resp:
        print("GraphQL errors (search entity): " + json.dumps(resp["errors"], indent=2), file=sys.stderr)
        sys.exit(1)

    entities = resp.get("data", {}).get("actor", {}).get("entitySearch", {}).get("results", {}).get("entities", [])
    if entities:
        print(json.dumps({"connection_id": entities[0]["guid"]}))
        sys.exit(0)

    if attempt < max_attempts:
        print("Attempt %d/%d: query AWS Connection Entity not yet indexed for setup '%s'; sleeping %ds..." % (attempt, max_attempts, setup_name, poll_interval), file=sys.stderr)
        time.sleep(poll_interval)

print("No query AWS Connection Entity found for setup '%s' after %d attempts (%ds total). Either the create step didn't actually run, or NGEP entitySearch is lagging beyond the budget — re-running terraform apply will retry." % (setup_name, max_attempts, max_attempts * poll_interval), file=sys.stderr)
sys.exit(1)
