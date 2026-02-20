{
  "name": "invoke",
  "slug": "invoke",
  "type": "custom",
  "retryable": true,
  "service_specification_id": "{{ env.Getenv "SERVICE_SPECIFICATION_ID" }}",
  "parameters": {
    "schema": {
      "type": "object",
      "required": [
        "scope_id"
      ],
      "properties": {
        "scope_id": {
          "type": "string"
        },
        "payload": {
          "type": "string",
          "description": "JSON payload to send to the Lambda function (optional)",
          "default": "{}"
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
