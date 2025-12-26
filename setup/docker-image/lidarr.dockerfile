FROM ghcr.io/hotio/lidarr:pr-plugins

RUN apk update
RUN apk add --no-cache kid3 imagemagick
