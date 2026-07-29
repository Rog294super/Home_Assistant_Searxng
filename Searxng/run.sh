#!/bin/bash
set -e

OPTIONS_FILE=/data/options.json
SETTINGS_FILE=/etc/searxng/settings.yml
SECRET_FILE=/data/generated_secret

mkdir -p /etc/searxng

if [ ! -f "$OPTIONS_FILE" ]; then
  echo "[searxng-addon] ERROR: $OPTIONS_FILE not found. This image must be run as a"
  echo "[searxng-addon] Home Assistant add-on (Supervisor writes this file for you)."
  exit 1
fi

BASE_URL=$(python3 -c "import json; print(json.load(open('/data/options.json'))['base_url'])")
INSTANCE_NAME=$(python3 -c "import json; print(json.load(open('/data/options.json'))['instance_name'])")
SECRET_KEY=$(python3 -c "import json; print(json.load(open('/data/options.json'))['secret_key'])")

# Keep the secret_key stable across restarts instead of regenerating it
# every boot, unless the user has explicitly set one in the options.
if [ -z "$SECRET_KEY" ] || [ "$SECRET_KEY" == "null" ]; then
  if [ -f "$SECRET_FILE" ]; then
    SECRET_KEY=$(cat "$SECRET_FILE")
  else
    SECRET_KEY=$(head -c 32 /dev/urandom | sha256sum | cut -d' ' -f1)
    echo "$SECRET_KEY" > "$SECRET_FILE"
    echo "[searxng-addon] Generated and stored a new secret_key in $SECRET_FILE"
  fi
fi

export BASE_URL INSTANCE_NAME SECRET_KEY
sed \
  -e "s|\${BASE_URL}|${BASE_URL}|g" \
  -e "s|\${INSTANCE_NAME}|${INSTANCE_NAME}|g" \
  -e "s|\${SECRET_KEY}|${SECRET_KEY}|g" \
  /settings.yml.template > "$SETTINGS_FILE"

# Turn the engines.* switches from the HA options UI into a settings.yml
# `engines:` override list. Because the template above sets
# use_default_settings: true, we only need to list the engines whose state
# should differ from upstream defaults — SearXNG merges this list into its
# full built-in catalog by matching on `name:`.
#
# IMPORTANT: each key below must exactly match an engine's `name:` field
# in SearXNG's own default settings.yml (case-sensitive, and some engines
# use spaces, e.g. "google images"). See DOCS.md for how to verify names.
ENGINES_YAML=""

for engine in google bing duckduckgo brave startpage qwant wikipedia github youtube reddit stackoverflow wolframalpha; do
  enabled=$(bashio::config "engines.${engine}")

  if [ "$enabled" = "true" ]; then
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

echo "[searxng-addon] Wrote $SETTINGS_FILE:"
cat "$SETTINGS_FILE"

export SEARXNG_SETTINGS_PATH="$SETTINGS_FILE"

# Locate the SearXNG image's own entrypoint script rather than hardcoding
# a single path — upstream has moved this file before between releases.
# If none of these match your pulled image, `docker exec` into the
# container and run `find / -iname '*entrypoint*' 2>/dev/null` to find it,
# then add the correct path to this list.
ENTRYPOINT_CANDIDATES=(
  "/usr/local/searxng/dockerfiles/docker-entrypoint.sh"
  "/usr/local/searxng/container/entrypoint.sh"
  "/usr/local/bin/docker-entrypoint.sh"
)

ORIG_ENTRYPOINT=""
for candidate in "${ENTRYPOINT_CANDIDATES[@]}"; do
  if [ -x "$candidate" ]; then
    ORIG_ENTRYPOINT="$candidate"
    break
  fi
done

if [ -z "$ORIG_ENTRYPOINT" ]; then
  echo "[searxng-addon] ERROR: could not find the base image's own entrypoint script."
  echo "[searxng-addon] Run: docker exec -it addon_searxng find / -iname '*entrypoint*'"
  echo "[searxng-addon] then add the resulting path to ENTRYPOINT_CANDIDATES in run.sh."
  exit 1
fi

echo "[searxng-addon] Handing off to $ORIG_ENTRYPOINT"
exec "$ORIG_ENTRYPOINT"
