#Base Image
FROM debian:12.2

#Don't ask confirmation
ENV DEBIAN_FRONTEND noninteractive

RUN apt update \
    && apt install --yes --no-install-recommends \
