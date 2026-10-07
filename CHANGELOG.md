# Changelog

All notable changes to this project are documented here.

## Unreleased

### Added

- First public release: one command that sets up Ubuntu 24.04 or 26.04 on ARM64 and x86_64 (desktops, WSL2, servers and VMs) with language toolchains, embedded and electronics tools, cloud and DevOps tools, CLI tools, developer tools and Git integration.
- Opt-in extras, including `configs` for a shell profile and tool configs from public repositories.
- Guides for WSL2, dual booting next to Windows, Linux on a Mac and choosing between them.
- Offline tests and a CI job that resolves every package on every supported release and architecture.

### Changed

- The README links the macOS and Windows bootstraps.
- `ACCESSIBILITY.md`, describing how a run reads and what a desktop gets.
- CI caps each job (10 minutes for tests, 20 for packages) and gives apt a 15-second network timeout, so an unreachable Ubuntu mirror fails fast instead of stretching a run for hours.
- Node.js 26 through nvm, the release that becomes the long-term support line in October 2026.
- On a desktop the `configs` extra links the High Contrast palette from terminal-config for Ptyxis, the terminal in Ubuntu 25.10 and later.
