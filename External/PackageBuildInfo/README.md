# PackageBuildInfo (vendored)

Fork of [DimaRU/PackageBuildInfo](https://github.com/DimaRU/PackageBuildInfo) that replaces the upstream **binary** helper with a Swift executable.

The helper runs `git` with **stderr discarded** (`FileHandle.nullDevice`). That prevents messages such as `fsmonitor_ipc__send_query: unspecified error on '.git/fsmonitor--daemon.ipc'` from being mixed into stdout and spliced into generated `packageBuildInfo.swift`, which previously produced invalid Swift and Xcode parse errors.

Regenerate build info by building any target that applies `PackageBuildInfoPlugin` (e.g. `PVUIBase`).
