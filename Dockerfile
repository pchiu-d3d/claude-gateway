FROM debian:bookworm-slim

ARG CLAUDE_VERSION=2.1.202

# Download and verify the Claude Code native binary
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -fL -o /usr/local/bin/claude \
      "https://downloads.claude.ai/claude-code-releases/${CLAUDE_VERSION}/linux-x64/claude" && \
    chmod +x /usr/local/bin/claude && \
    apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Bake config (non-secret values); secrets injected at runtime via ${ENV_VAR}
COPY gateway.yaml /etc/claude/gateway.yaml

# Gateway needs a writable dir (minimal images have no home)
ENV CLAUDE_CONFIG_DIR=/tmp/.claude
ENV CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

EXPOSE 8080
ENTRYPOINT ["claude", "gateway", "--config", "/etc/claude/gateway.yaml"]
