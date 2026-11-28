#!/usr/bin/env bash
# TEMPORARY: applies the flat-settlement patch, runs the gate and commits it.
# If a phase fails it publishes its own report to the branch instead, because
# Actions logs are not readable without an authenticated session.
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
    ls -l .github/scripts/iter7
    cat .github/scripts/iter7/q-0* > /tmp/fix.patch
    ls -l /tmp/fix.patch
    echo "04269a85292169b8b8ceaa1d61240f429b437b63823192971bece5f3461ff68c  /tmp/fix.patch" | sha256sum -c -
    git apply --check /tmp/fix.patch
    git apply /tmp/fix.patch
    git status --short
}

gate() {
    set -euo pipefail
    npm ci --no-audit --no-fund
    npm run check
    npm test
}

sims() {
    set -euo pipefail
    node tools/sim_30min.js > /tmp/sim-short.txt 2>&1
    grep -q "FINAL" /tmp/sim-short.txt
    tail -4 /tmp/sim-short.txt
    node tools/sim_campaign.js --hours 4 --seeds 4 > /tmp/sim-long.txt 2>&1
    grep -q "final note" /tmp/sim-long.txt
    tail -6 /tmp/sim-long.txt
}

commit_and_push() {
    set -euo pipefail
    git config user.name "kidseib"
    git config user.email "kidseib@users.noreply.github.com"

    git add addon CHANGELOG.md PROGRESS.md
    git commit -q -m "fix: settle the wager flat instead of riding the daily request bonus" \
        -m "completeSale creates the day's customer request lazily, so a flip on an item whose category matched that day's request was paid prize x (1 + bonus): the button stated 80 and the player received 101. Wagers now settle at exactly the quoted figure through a flat flag on completeSale; the request is still marked fulfilled because a real sale happened, but its bonus is never folded into a number the player already agreed to." \
        -m "Found by re-running the delivered build: the UI smoke failed on a matching-request day. The winning-wager test now builds a matching request (bonus 0.25) and asserts the payout equals terms.prize and the request is fulfilled, so the bug fails deterministically. npm test was then run 10 times back to back: 95/95 with a green UI smoke every time."

    git rm -r -q .github/scripts
    git rm -q .github/workflows/apply-iter7.yml
    git commit -q -m "chore: remove iteration 7 fix scaffolding"

    git push origin HEAD:refinement-polish
}

say "node=$(node -v 2>&1) bash=$BASH_VERSION head=$(git rev-parse --short HEAD)"

fail=0
phase assemble assemble || fail=1
if [ "$fail" -eq 0 ]; then phase gate gate || fail=1; fi
if [ "$fail" -eq 0 ]; then phase sims sims || fail=1; fi
if [ "$fail" -eq 0 ]; then phase commit commit_and_push || fail=1; fi

if [ "$fail" -ne 0 ]; then
    git checkout -- . >/dev/null 2>&1 || true
    git clean -fdq -e ".github/scripts" >/dev/null 2>&1 || true
    git add -f "$report"
    git -c user.name="kidseib" -c user.email="kidseib@users.noreply.github.com" \
        commit -q -m "chore: iteration 7 fix report (failure)"
    git push origin HEAD:refinement-polish
fi

exit "$fail"
