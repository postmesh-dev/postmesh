# postmesh

Postmesh is a local-first email sync and query tool.

This repository is the new canonical home for Postmesh releases and source.
Release binaries are published as GitHub Release assets. Installer metadata
lives in `artifacts/`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/postmesh-dev/postmesh/refs/tags/latest/install.sh | sh
```

## Layout

```text
artifacts/
  latest.json
  releases/
    0.1.0.json
    checksums-0.1.0.txt
install.sh
uninstall.sh
```

## Notes

- Release archives are attached to GitHub Releases and are not committed to git.
- Installer metadata is committed so `install.sh` can resolve versions and checksums.
- Source code can be added here later without mixing binaries into the repository root.
