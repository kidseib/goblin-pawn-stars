#!/usr/bin/env bash
# TEMPORARY: applies the README correction, re-runs the gate and pushes it.
set -u

cd "$(git rev-parse --show-toplevel)"
report=".github/scripts/iter7/report.txt"

if [ -f "$report" ]; then
    echo "report already published; nothing to do"
    exit 0
fi

: > "$report"
say() { printf '%s\n' "$@" >> "$report"; }

phase() {
    local name="$1"
    shift
    say ""
    say "===== $name"
    "$@" >> "$report" 2>&1
    local code=$?
    say "----- $name exit=$code"
    return $code
}

assemble() {
    set -euo pipefail
    cat .github/scripts/iter7/r-00 > /tmp/r.patch
    echo "bb87617e4577ad559d853c1399a8a290af39848e8ac27bf493e94c96b9cd66a5  /tmp/r.patch" | sha256sum -c -
    git apply --check /tmp/r.patch
    git apply /tmp/r.patch
    git status --short
}

gate() {
    set -euo pipefail
    npm ci --no-audit --no-fund
    npm run check
    npm test
}

commit_and_push() {
    set -euo pipefail
    git config user.name "kidseib"
    git config user.email "kidseib@users.noreply.github.com"

    git add README.md
    git commit -q -m "docs: correct the README line count after the flat-settlement fix" \
        -m "The syntax check now reports 69 files and 21,669 lines; the testing-status section still said 21,661."

    git rm -r -q .github/scripts
    git rm -q .github/workflows/apply-iter7.yml
    git commit -q -m "chore: remove documentation scaffolding"

    git push origin HEAD:refinement-polish
}

say "node=$(node -v 2>&1) head=$(git rev-parse --short HEAD)"

fail=0
phase assemble assemble || fail=1
if [ "$fail" -eq 0 ]; then phase gate gate || fail=1; fi
if [ "$fail" -eq 0 ]; then phase commit commit_and_push || fail=1; fi

if [ "$fail" -ne 0 ]; then
    git checkout -- . >/dev/null 2>&1 || true
    git clean -fdq -e ".github/scripts" >/dev/null 2>&1 || true
    git add -f "$report"
    git -c user.name="kidseib" -c user.email="kidseib@users.noreply.github.com" \
        commit -q -m "chore: readme correction report (failure)"
    git push origin HEAD:refinement-polish
fi

exit "$fail"
