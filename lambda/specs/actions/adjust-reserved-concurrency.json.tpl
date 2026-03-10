{
  "name": "Adjust reserved concurrency",
  "slug": "adjust-reserved-concurrency",
  "type": "custom",
  "retryable": true,
  "service_specification_id": "{{ env.Getenv "SERVICE_SPECIFICATION_ID" }}",
  "icon": "material-symbols:expand-rounded",
  "annotations": {
    "show_on": [],
    "runs_over": "scope"
  },
  "enabled_when": "",
  "parameters": {
    "schema": {
      "type": "object",
      "required": ["scope_id", "value"],
      "properties": {
        "scope_id": {
          "type": "number",
          "readOnly": true,
          "visibleOn": []
        },
        "value": {
          "type": "integer",
          "description": "Number of reserved concurrent executions (0 to remove reservation)",
          "minimum": 0
        }
      }
    },
    "values": {}
  },
  "results": {
    "schema": {
      "type": "object",
      "required": [],
      "properties": {}
    },
    "values": {}
  }
}
