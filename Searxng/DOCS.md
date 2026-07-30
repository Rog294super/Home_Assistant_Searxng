# SearXNG (local add-on)

A self-built Home Assistant add-on for SearXNG that:

- Exposes per-engine on/off switches in the add-on Configuration UI
- Runs on the host network directly, so it's reachable at `<host-ip>:<PORT>`
  with **no** `homeassistant.local:8123/api/hassio_ingress/...` path prefix
- Is meant to sit behind your own `searxng.lan` / `searxng.local` hostnames
  via DNS, not via HA's ingress proxy

## Installing it

1. Install the app through adding the URL: `https://github.com/Rog294super/Home_Assistant_Searxng` to repositories at **Settings → Add-ons → Add-on Store → : → Repositories → ADD button bottom right **,
2. In HA: **Settings → Add-ons → Add-on Store → ⋮ → Check for updates**,
   then scroll down to **Local add-ons** — SearXNG should appear there.
3. Install, set your engine switches under **Configuration**, then **Start**.
4. Check the **Log** tab — it prints the generated `settings.yml` on every
   boot, so you can confirm your toggles actually took effect.

Building happens on-device from the Dockerfile, so first install will take some time possible on lower power devices.

## Getting `searxng.lan` / `searxng.local` working

`host_network: true` in `config.yaml` puts the container directly on your
LAN — it does not create the hostname for you. You still need DNS to point
those names at your Home Assistant host's IP. If you're already running
**AdGuard Home** as a HAOS add-on, the easiest path is DNS rewrites there:

1. AdGuard Home → **Filters → DNS rewrites → Add**
2. Domain: `searxng.lan` → IP: your HA host's LAN IP
3. Repeat for `searxng.local` → same IP

Then browse to `http://searxng.lan:<PORT>/`, `http://searxng.local:<PORT>` or use the open webgui through apps menu.

**Caveat on `.local` from Windows clients:** Windows treats `.local` as an
mDNS/LLMNR suffix by default and may try to resolve it via multicast on the
local segment *before* ever asking AdGuard, so the rewrite can be ignored
even though it's configured correctly. `searxng.lan` doesn't have this
problem since `.lan` isn't a reserved multicast TLD. If `.local` is flaky
from a given machine, `searxng.lan` is the more reliable one to standardize
on — or fall back to true mDNS (Avahi) instead of a DNS rewrite for that
specific host.

**No clean port-80 URL out of the box:** SearXNG's image listens on 18080
internally, and `host_network` just forwards that straight through, so the
URL includes `:<PORT>`. If you want a bare `http://searxng.lan/` with no
port, put it behind a nginx reverse proxy or another reverse proxy `searxng.lan:<PORT>` or `searxng.local`→ `127.0.0.1:<PORT>` or `LAN-IP:<PORT>`.

## Verifying engine names

Each key under `engines:` in `config.yaml`'s `options` must exactly match
an engine's `name:` field in SearXNG's own default settings — some have
spaces (`"google images"`) and are case-sensitive. `google`, `bing`,
`duckduckgo`, `wikipedia`, `github`, `youtube`, and `reddit` are safe bets
as-is; double-check `brave`, `startpage`, `qwant`, `stackoverflow`, and
`wolframalpha` before relying on them. To see the authoritative list for
the exact image version you're running:

```bash
docker run --rm --entrypoint cat searxng/searxng:latest /usr/local/searxng/searx/settings.yml \
  | grep -A1 "name:" | less
```

Add new engines by adding more `key: true/false` pairs under both
`options.engines` and `schema.engines` in `config.yaml` — the name just
needs to match what you find there.

