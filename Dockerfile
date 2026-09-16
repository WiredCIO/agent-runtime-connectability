# ConnectAbility agent runtime: Paperclip's Claude runtime + Power Platform ALM tooling.
#
# Base is the image the ConnectAbility Sandbox already runs, so the Claude CLI,
# Node and the Paperclip runtime contract stay exactly as Paperclip expects.
# Only .NET and pac are added on top.
#
# NOTE: base is Node 22, so agents on this image must run engine: "cli".
# ACP requires Node >= 24.11 and will fail with adapter_engine_unavailable.
FROM ghcr.io/paperclipai/agent-runtime-claude:git-4f539625f7b63541d1beae1341220702638b7677

USER root

# .NET SDK installed system-wide (not $HOME) so it resolves for every user the
# sandbox runs as — the login PTY and the run process are not always the same uid.
ENV DOTNET_ROOT=/opt/dotnet \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    PATH=/opt/dotnet:/opt/dotnet/tools:$PATH

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl libicu-dev; \
    rm -rf /var/lib/apt/lists/*; \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh; \
    chmod +x /tmp/dotnet-install.sh; \
    /tmp/dotnet-install.sh --channel 10.0 --install-dir "$DOTNET_ROOT"; \
    rm -f /tmp/dotnet-install.sh; \
    dotnet --version

# Power Platform CLI as a global tool. --tool-path keeps it out of a per-user
# home so it survives whatever uid the sandbox assigns.
RUN set -eux; \
    dotnet tool install Microsoft.PowerApps.CLI.Tool --tool-path /opt/dotnet/tools; \
    pac help > /dev/null

# Dataverse MCP local proxy, pre-pulled so runs don't pay an npx fetch each time.
# Unused on the remote-endpoint MCP path, but harmless and useful for `pac` auth debugging.
RUN npm install -g @microsoft/dataverse || echo "WARN: @microsoft/dataverse not installed; remote MCP path unaffected"

# Base image runs as the numeric uid 1000:1000 with no passwd entry, so `USER node`
# fails with "no matching entries in passwd file". Restore the numeric id exactly.
USER 1000:1000

RUN set -eux; \
    claude --version; \
    pac help > /dev/null; \
    node --version
