# Releases:
#   https://hub.docker.com/_/docker/tags
FROM docker:28

LABEL maintainer="Josh.5 <jsunnex@gmail.com>"

RUN \
    echo "**** Install entrypoint dependencies ****" \
        && apk add --no-cache \
            bash \
            bc \
            cgroup-tools \
            coreutils \
            curl \
            gettext \
            wget \
        && wget -q "https://github.com/mikefarah/yq/releases/download/v4.43.1/yq_linux_amd64" \
            -O "/usr/bin/yq" \
        && chmod +x "/usr/bin/yq" \
    && \
    echo

COPY overlay/ /

ENTRYPOINT ["/entrypoint.sh"]
CMD []
