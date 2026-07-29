# We build straight on top of the official multi-arch SearXNG image rather
# than a Home Assistant base image, since it already ships the full Python
# search engine stack. This image is a multi-arch manifest, so the same
# FROM line resolves correctly on amd64/aarch64/armv7 hosts.
FROM searxng/searxng:latest

# jq: parse /data/options.json (the values you set in the HA add-on UI)
# gettext: gives us envsubst for templating settings.yml
RUN apk add --no-cache jq gettext

COPY run.sh /run.sh
COPY settings.yml.template /settings.yml.template
RUN chmod a+x /run.sh

ENTRYPOINT [ "/run.sh" ]
