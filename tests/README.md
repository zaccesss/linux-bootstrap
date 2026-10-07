# Tests

`bootstrap-test.sh` runs the bootstrap offline. apt-get and sudo are replaced with stubs that
record what they were asked to do. Platform detection reads fixture files, so every supported and
unsupported platform is checked on one machine without installing anything.

It covers:

- the repository structure and stage permissions
- `--help`, `--list`, `--with` validation and `--extras-only`
- refusing unsupported releases, distributions and architectures
- full default runs on Ubuntu 24.04 and 26.04, ARM64 and x86_64, including the per-release packages
- WSL (systemd in `wsl.conf`, wslu on 24.04, the browser note on 26.04) and QEMU desktop VMs
- optional extras, including desktop-only extras being skipped on a server
- the ArduPilot installer patch for an Ubuntu release it does not know yet
- every stage's final command check, with a missing command making it fail

Run it on any Ubuntu machine:

```bash
./tests/bootstrap-test.sh
```

The other half of the checking happens in CI: the **packages** job resolves every real package on
every supported release and architecture. See [docs/platforms.md](../docs/platforms.md).
