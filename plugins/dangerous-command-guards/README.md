# dangerous-command-guards

Blocks or requires confirmation for destructive and privileged commands.

## Denied commands

| Command | Risk                                          |
| ------- | --------------------------------------------- |
| `dd`    | Can overwrite entire disks                    |
| `mkfs`  | Creates filesystems, destroying existing data |

## Ask (requires confirmation)

| Command    | Risk                                                  |
| ---------- | ----------------------------------------------------- |
| `op`       | 1Password CLI — accesses secrets vault                |
| `open`     | Launches applications — side effects outside terminal |
| `sudo`     | Privilege escalation                                  |
| `trash -r` | Recursive trash — irreversible bulk deletion          |
