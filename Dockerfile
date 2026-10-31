# syntax=docker/dockerfile:1

ARG OPENCODE_VERSION=latest
FROM ghcr.io/anomalyco/opencode:${OPENCODE_VERSION}

LABEL org.opencontainers.image.title="OPEN_CODE_VPS"
LABEL org.opencontainers.image.description="OpenCode server packaged for VPS and Coolify deployments"

RUN apk add --no-cache \
      bash \
      ca-certificates \
      curl \
      git \
      openssh-client \
    && git --version

ENV HOME=/root
ENV OPENCODE_DISABLE_AUTOUPDATE=true
ENV OPENCODE_SERVER_USERNAME=opencode

WORKDIR /workspace

EXPOSE 4096

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS -u "${OPENCODE_SERVER_USERNAME}:${OPENCODE_SERVER_PASSWORD}" http://127.0.0.1:4096/global/health || exit 1

ENTRYPOINT ["opencode"]
CMD ["web", "--hostname", "0.0.0.0", "--port", "4096"]
