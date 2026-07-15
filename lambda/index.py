"""
WeatherWatch Phase 2 handler.

The point of this phase: make ONE real external API call from inside the
handler, with the API key read from Secrets Manager at runtime (never
hard-coded), then do something real with the result — here we transform it
and store it in DynamoDB.

Flow:
  1. Read the secret's *name* from an env var, fetch its value from Secrets
     Manager at runtime. The key never appears in code or Terraform state.
  2. Call OpenWeatherMap once for the requested city.
  3. Transform the response into a small record.
  4. PutItem into the on-demand DynamoDB table.
  5. Return the transformed record through the API Gateway front door.

Only the standard library + boto3 (bundled in the Lambda runtime) are used,
so there is nothing to pip-install or package.
"""

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

import boto3

_sm = boto3.client("secretsmanager")
_ddb = boto3.client("dynamodb")

SECRET_NAME = os.environ["OWM_SECRET_NAME"]
TABLE_NAME = os.environ["TABLE_NAME"]
DEFAULT_CITY = os.environ.get("DEFAULT_CITY", "London")

OWM_URL = "https://api.openweathermap.org/data/2.5/weather"


def _get_api_key():
    """Read the API key from Secrets Manager at runtime.

    Accepts either a JSON secret like {"api_key": "..."} (how Phase 1 stored
    it) or a raw string secret. The value is never logged.
    """
    raw = _sm.get_secret_value(SecretId=SECRET_NAME)["SecretString"]
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            for k in ("api_key", "OWM_API_KEY", "apiKey", "key"):
                if parsed.get(k):
                    return parsed[k]
        return raw.strip()
    except (ValueError, TypeError):
        return raw.strip()


def _call_weather_api(city, api_key):
    """The single external API call for this phase."""
    query = urllib.parse.urlencode({"q": city, "appid": api_key, "units": "metric"})
    url = f"{OWM_URL}?{query}"
    req = urllib.request.Request(url, headers={"User-Agent": "weatherwatch/2.0"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _transform(city, payload):
    """Reshape the raw API response into a compact record."""
    main = payload.get("main", {}) or {}
    weather = (payload.get("weather") or [{}])[0]
    return {
        "id": f"{city.lower()}#{int(time.time())}",
        "city": payload.get("name", city),
        "temp_c": main.get("temp"),
        "feels_like_c": main.get("feels_like"),
        "humidity": main.get("humidity"),
        "conditions": weather.get("description"),
        "fetched_at": int(time.time()),
    }


def _to_ddb_item(record):
    """Marshal the record into the DynamoDB attribute-value format."""
    item = {"id": {"S": record["id"]}, "city": {"S": str(record["city"])}}
    if record.get("conditions"):
        item["conditions"] = {"S": str(record["conditions"])}
    for num_field in ("temp_c", "feels_like_c", "humidity", "fetched_at"):
        val = record.get(num_field)
        if val is not None:
            item[num_field] = {"N": str(val)}
    return item


def handler(event, context):
    params = (event.get("queryStringParameters") or {}) if isinstance(event, dict) else {}
    city = (params or {}).get("city") or DEFAULT_CITY

    try:
        api_key = _get_api_key()
        raw = _call_weather_api(city, api_key)
        record = _transform(city, raw)
        _ddb.put_item(TableName=TABLE_NAME, Item=_to_ddb_item(record))

        body = {
            "message": "Fetched from OpenWeatherMap and stored in DynamoDB",
            "stored_in": TABLE_NAME,
            "item_id": record["id"],
            "result": record,
        }
        status = 200
    except urllib.error.HTTPError as e:
        body = {"error": "external_api_error", "status": e.code, "detail": e.reason, "city": city}
        status = 502
    except Exception as e:  # noqa: BLE001 - surface any failure as JSON
        body = {"error": type(e).__name__, "detail": str(e), "city": city}
        status = 500

    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
