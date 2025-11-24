# GitHub Plugin

GitHub Actions troubleshooting and CI/CD automation for Claude Code.

## Features

- **GitHub Actions Debugging**: Fix failing CI/CD workflows
- **Workflow Analysis**: Examine failed runs and logs
- **Commit-based Fixes**: Target fixes to specific commits

## Commands

- `/gha` - Fix failing GitHub Actions for the current commit
  - Fetches latest refs from origin
  - Finds failing checks for HEAD commit
  - Analyzes failure logs
  - Fixes identified issues
  - Creates fixup commit

## Usage

When you have a failing GitHub Actions run on your current commit:

```bash
/gha
```

The command will:

1. Fetch the latest git refs
2. List recent workflow runs for your commit
3. View details of failed runs
4. Show only failed job logs
5. Analyze and fix the issues
6. Create a fixup commit targeting HEAD
