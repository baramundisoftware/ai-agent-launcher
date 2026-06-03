# AI Agent Bubblewrap Launcher

Lightweight bash scripts that run AI coding agents in a fully sandboxed environment using [bubblewrap](https://github.com/containers/bubblewrap). Each agent binary never executes outside the sandbox — updates and version checks happen inside.

| Script                | Agent                                                       |
| --------------------- | ----------------------------------------------------------- |
| `claude-launcher.sh`  | [Claude Code](https://claude.ai/code)                       |
| `copilot-launcher.sh` | [GitHub Copilot CLI](https://github.com/github/copilot-cli) |

## Features

- Agent binary never runs outside the sandbox
- Only the project directory is writable inside the sandbox
- Restricts read access to the rest of the filesystem
- Automatic binary updates on every launch
- Small single bash script per agent, minimal overhead

## Requirements

Linux or WSL2 with bubblewrap and curl:

```bash
sudo apt install bubblewrap curl  # Ubuntu/Debian
```

## Installation

### Claude Code

```bash
mkdir -p "$HOME/.local/bin"
cp claude-launcher.sh "$HOME/.local/bin/claude"
chmod +x "$HOME/.local/bin/claude"
# Add $HOME/.local/bin to PATH if not already present
export PATH="$HOME/.local/bin:$PATH"
```

### GitHub Copilot CLI

```bash
mkdir -p "$HOME/.local/bin"
cp copilot-launcher.sh "$HOME/.local/bin/copilot-sandboxed"
chmod +x "$HOME/.local/bin/copilot-sandboxed"
# Add $HOME/.local/bin to PATH if not already present
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

### Claude Code

```bash
claude            # Launch in current directory
claude mcp list   # List installed MCP servers
```

### GitHub Copilot CLI

```bash
copilot-sandboxed              # Launch in current directory
copilot-sandboxed explain      # Explain a command
```

## Adding extra tools

The sandbox only exposes the host's system tools (read-only), so package managers
like [`uv`](https://docs.astral.sh/uv/)/`uvx` are not present by default. Because the
sandbox home (`~/.claude-sandbox/home`) is persistent and `~/.local/bin` is already on
`PATH`, you can install such tools **once** from inside a running agent and they remain
available on every future launch — no need to reinstall each session.

For example, have the agent run a shell command (in Claude Code, prefix it with `!`):

```bash
! curl -LsSf https://astral.sh/uv/install.sh | sh
```

`uv` and `uvx` install into `~/.local/bin` and are immediately callable.

## Comparison

|                             | **AI Agent Launcher**  | **Built-in Sandbox**                                                                                                                                                       | **Dev Container + [Claude Feature](https://github.com/devcontainers/features)** | **[claudebox](https://github.com/RchGrav/claudebox)**                                                         | **[ClaudeCage](https://github.com/PACHAKUTlQ/ClaudeCage)**                                                                                  | **[cco](https://github.com/nikvdp/cco)**                                                                            |
| --------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Technology**              | Bubblewrap             | Bubblewrap + socat                                                                                                                                                         | Dev Container + Docker/Podman                                                   | Docker                                                                                                        | RunImage + Bubblewrap                                                                                                                       | Multiple                                                                                                            |
| **Easy to review**          | Yes (~100 lines)       | ❌ No (closed source)                                                                                                                                                      | Yes (config files)                                                              | ❌ No (thousands of lines)                                                                                    | Moderate (build script)                                                                                                                     | ❌ No (thousands of lines)                                                                                          |
| **Binary isolation**        | Yes                    | ❌ Only "BashTool"                                                                                                                                                         | Container only                                                                  | Container only                                                                                                | Portable executable                                                                                                                         | Yes                                                                                                                 |
| **Protect private files**   | Yes (selective mounts) | ❌ No (--ro-bind / /) [1](https://github.com/anthropic-experimental/sandbox-runtime/blob/9f59523e125e823788c9be071c7e0eb6832dd4d5/src/sandbox/linux-sandbox-utils.ts#L650) | Yes (workspace only)                                                            | Yes [1](https://github.com/RchGrav/claudebox/blob/a7799bb5a7801f03f1343009b1cdfdaaa83c7fb6/lib/docker.sh#L88) | Yes [1](https://github.com/PACHAKUTlQ/ClaudeCage/blob/05ba44a5c67cfddb661683b0c6a98dffa180cc29/README.md#sandbox-mounts--isolation-default) | ❌ No (--ro-bind / /) [1](https://github.com/nikvdp/cco/blob/4245f7621f0c9236e8b1daeae43be6d4f003f948/sandbox#L191) |
| **Filters network traffic** | No                     | Yes (socat proxy + seccomp)                                                                                                                                                | No                                                                              | No                                                                                                            | No                                                                                                                                          | No                                                                                                                  |
| **WSL Support**             | Yes                    | Yes ([since 2026](https://github.com/anthropics/claude-code/issues/10567))                                                                                                 | Yes (Docker/Podman)                                                             | Yes (Docker)                                                                                                  | Yes                                                                                                                                         | Yes                                                                                                                 |
| **Overhead**                | Minimal                | Minimal                                                                                                                                                                    | Container runtime + layers                                                      | Docker daemon + layers                                                                                        | Moderate                                                                                                                                    | Moderate                                                                                                            |
| **Startup time**            | Instant                | Instant                                                                                                                                                                    | Container startup                                                               | Container startup                                                                                             | Instant                                                                                                                                     | Instant                                                                                                             |
| **Setup complexity**        | Single script          | Built-in                                                                                                                                                                   | Dev Container config                                                            | Moderate                                                                                                      | Build script                                                                                                                                | Single script                                                                                                       |
| **Provides matching tools** | System tools           | System tools                                                                                                                                                               | Yes (Customizable)                                                              | Pre-configured profiles                                                                                       | System tools                                                                                                                                | System tools                                                                                                        |
| **Best for**                | Local development      | Always, nesting possible                                                                                                                                                   | VSCode/IDEs integration                                                         | Local development                                                                                             | Local development                                                                                                                           | Local development                                                                                                   |

## References

- [Claude Code Sandboxing (Anthropic)](https://www.anthropic.com/engineering/claude-code-sandboxing)
- [Claude Code Docs - Sandboxing](https://code.claude.com/docs/en/sandboxing)
