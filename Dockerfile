FROM alpine:3.23.2

RUN apk add --no-cache jq curl docker-cli

COPY --chmod=755 update-plex.sh /usr/local/bin/update-plex.sh

CMD ["/usr/local/bin/update-plex.sh"]
