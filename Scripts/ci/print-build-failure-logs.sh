#!/usr/bin/env bash
# Report the release transcript AND the archive's unformatted xcodebuild log.
set -euo pipefail

found=0
for logfile in "$@"; do
    [[ -f "$logfile" ]] || continue
    found=1
    echo "::group::Compiler/linker diagnostics: $logfile"
    grep -E ': (fatal )?error:|^::error' "$logfile" | tail -100 \
        || echo "(no compiler diagnostics found)"
    echo "::endgroup::"
    # Script/signing failures may appear only in the failed-command block or tail.
    echo "::group::Failed build commands: $logfile"
    grep -A15 'The following build commands failed:' "$logfile" \
        || echo "(no 'build commands failed' summary found)"
    echo "::endgroup::"
    echo "::group::Last 100 lines: $logfile"
    tail -100 "$logfile"
    echo "::endgroup::"
done

if [[ "$found" == 0 ]]; then
    echo '::warning::No build logs found; the release may have failed before logging started'
fi
