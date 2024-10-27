# Releases:
#   https://hub.docker.com/_/docker/tags
FROM docker:27

LABEL maintainer="Josh.5 <jsunnex@gmail.com>"

RUN \
    echo "**** Install entrypoint dependencies ****" \
        && apk add --no-cache \
            bash \
            wget \
    && \
    echo

COPY overlay/ /

ENTRYPOINT ["/entrypoint.sh"]
CMD []
