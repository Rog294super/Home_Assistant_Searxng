# We build straight on top of the official multi-arch SearXNG image rather
# than a Home Assistant base image, since it already ships the full Python
# search engine stack. This image is a multi-arch manifest, so the same
# FROM line resolves correctly on amd64/aarch64/armv7 hosts.
FROM searxng/searxng:latest

COPY run.sh /run.sh
COPY settings.yml.template /settings.yml.template

RUN chmod +x /run.sh

RUN find / -type f -executable -name '*searx*' 2>/dev/null

ENTRYPOINT ["/run.sh"]
