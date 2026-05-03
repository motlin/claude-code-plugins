# privacy

Disables all telemetry, error reporting, and non-essential model calls.

## Environment variables set

| Variable                            | Effect                                                    |
| ----------------------------------- | --------------------------------------------------------- |
| `DISABLE_BUG_COMMAND`               | Disables the `/bug` command                               |
| `DISABLE_ERROR_REPORTING`           | Prevents sending error reports to Anthropic               |
| `DISABLE_NON_ESSENTIAL_MODEL_CALLS` | Prevents background model calls not initiated by the user |
| `DISABLE_TELEMETRY`                 | Disables all usage telemetry                              |
