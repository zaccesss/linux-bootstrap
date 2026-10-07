# Workflows

| Workflow | Runs on | What it does |
| --- | --- | --- |
| [`bootstrap.yml`](bootstrap.yml) | Push to `main`, every pull request | Verifies the ARM64 Ubuntu platform, checks Bash syntax, runs ShellCheck and runs the bootstrap test suite |
| [`shellcheck.yml`](shellcheck.yml) | Push to `main`, every pull request | Lints every shell script under `bootstrap/` |
| [`markdownlint.yml`](markdownlint.yml) | Push to `main`, every pull request | Lints every markdown file against [`.markdownlint.json`](../../.markdownlint.json) |

Runnable manually via `workflow_dispatch` from the Actions tab where the workflow supports it.

Dependency updates are configured separately in [`../dependabot.yml`](../dependabot.yml), covering the GitHub Actions used across the workflows above.
