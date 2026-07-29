#!/bin/bash
set -e

OPTIONS_FILE=/data/options.json
SETTINGS_FILE=/etc/searxng/settings.yml
SECRET_FILE=/data/generated_secret

mkdir -p /etc/searxng

if [ ! -f "$OPTIONS_FILE" ]; then
  echo "[searxng-addon] ERROR: $OPTIONS_FILE not found."
  exit 1
fi

BASE_URL=$(python3 -c "import json; print(json.load(open('$OPTIONS_FILE'))['base_url'])")
INSTANCE_NAME=$(python3 -c "import json; print(json.load(open('$OPTIONS_FILE'))['instance_name'])")
SECRET_KEY=$(python3 -c "import json; print(json.load(open('$OPTIONS_FILE'))['secret_key'])")

if [ -z "$SECRET_KEY" ] || [ "$SECRET_KEY" = "None" ] || [ "$SECRET_KEY" = "null" ]; then
  if [ -f "$SECRET_FILE" ]; then
    SECRET_KEY=$(cat "$SECRET_FILE")
  else
    SECRET_KEY=$(head -c 32 /dev/urandom | sha256sum | cut -d' ' -f1)
    echo "$SECRET_KEY" > "$SECRET_FILE"
    echo "[searxng-addon] Generated and stored a new secret_key"
  fi
fi

export BASE_URL INSTANCE_NAME SECRET_KEY

sed \
  -e "s|\${BASE_URL}|${BASE_URL}|g" \
  -e "s|\${INSTANCE_NAME}|${INSTANCE_NAME}|g" \
  -e "s|\${SECRET_KEY}|${SECRET_KEY}|g" \
  /settings.yml.template > "$SETTINGS_FILE"


ENGINES_YAML=""

for engine in google bing duckduckgo brave startpage qwant wikipedia github youtube reddit stackoverflow wolframalpha; do
  enabled=$(python3 -c "import json; print(json.load(open('$OPTIONS_FILE'))['engines'].get('$engine', False))")

  if [ "$enabled" = "True" ]; then
    disabled="false"
  else
    disabled="true"
  fi

  ENGINES_YAML="${ENGINES_YAML}  - name: \"${engine}\"
    disabled: ${disabled}
"
done

{
  echo ""
  echo "engines:"
  echo "$ENGINES_YAML"
} >> "$SETTINGS_FILE"

echo "[searxng-addon] Generated settings:"
cat "$SETTINGS_FILE"

export SEARXNG_SETTINGS_PATH="$SETTINGS_FILE"

echo "[searxng-addon] Starting SearXNG"
find /usr/local -name python -type f 2>/dev/null
exec /usr/local/searxng/.venv/bin/python -m searx.webapp --host 0.0.0.0 --port 8080 