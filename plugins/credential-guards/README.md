# credential-guards

Prevents Claude Code from reading credential and secret files.

## Denied paths

| Path                     | Contents                      |
| ------------------------ | ----------------------------- |
| `~/.aws/**`              | AWS credentials and config    |
| `~/.azure/**`            | Azure credentials             |
| `~/.config/gh/**`        | GitHub CLI tokens             |
| `~/.docker/config.json`  | Docker registry auth          |
| `~/.gem/credentials`     | RubyGems API key              |
| `~/.git-credentials`     | Git credential store          |
| `~/.gnupg/**`            | GPG keys and trust database   |
| `~/.kube/**`             | Kubernetes configs and tokens |
| `~/.npm/**`              | npm cache and tokens          |
| `~/.npmrc`               | npm registry auth             |
| `~/.pypirc`              | PyPI credentials              |
| `~/Library/Keychains/**` | macOS Keychain                |

## Ask (requires confirmation)

| Path        | Reason                                                                |
| ----------- | --------------------------------------------------------------------- |
| `~/.ssh/**` | SSH keys and config — legitimate uses exist (reading `~/.ssh/config`) |
