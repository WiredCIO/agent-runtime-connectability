# agent-runtime-connectability

Paperclip agent runtime for the ConnectAbility Dynamics 365 engagement.

`ghcr.io/paperclipai/agent-runtime-claude` plus the Power Platform ALM toolchain:

- .NET SDK 10 at `/opt/dotnet`
- Power Platform CLI (`pac`) at `/opt/dotnet/tools`
- `@microsoft/dataverse` MCP local proxy

Installed system-wide rather than under `$HOME`, so the tools resolve whatever uid the
sandbox assigns to a run or a login PTY.

## Constraint

The base image ships **Node 22**. Paperclip's Claude ACP engine requires Node >= 24.11, so any
agent on this image must be pinned to `engine: "cli"` or its runs fail with
`adapter_engine_unavailable`.

## Use

Set as the image on the Paperclip sandbox environment:

```
ghcr.io/wiredcio/agent-runtime-connectability:latest
```

Built and published by GitHub Actions on every push to `Dockerfile`.

## Note on networking

This image carried Tailscale briefly, to let sandboxes reach Paperclip's MCP
gateway at its tailnet hostname. That never worked: Daytona boots sandboxes with
its own init and ignores an image's `ENTRYPOINT`, and Paperclip injects env vars at
exec time rather than container start, so there was no point at which a join could
run with a key. Paperclip is now reachable at a public hostname instead, so the
sandbox needs no tailnet membership.
