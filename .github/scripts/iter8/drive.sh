#!/usr/bin/env bash
# TEMPORARY: applies the A-board patch, runs the gate and commits it.
# A failure publishes this report to the branch, because Actions logs need auth.
set -u

cd "$(git rev-parse --show-toplevel)"
report=".github/scripts/iter8/report.txt"

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
    ls -l .github/scripts/iter8
    cat .github/scripts/iter8/b-0* > /tmp/iter8.patch.xz
    ls -l /tmp/iter8.patch.xz
    echo "465398746e4f5ce40e67f1e9e505f5168b415ae96b73e2744011a87b95f4f305  /tmp/iter8.patch.xz" | sha256sum -c -
    xz -dc /tmp/iter8.patch.xz > /tmp/iter8.patch
    ls -l /tmp/iter8.patch
    git apply --unidiff-zero --check /tmp/iter8.patch
    git apply --unidiff-zero /tmp/iter8.patch
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
    grep -q "Marta done" /tmp/sim-long.txt
    tail -6 /tmp/sim-long.txt
}

commit_and_push() {
    set -euo pipefail
    git config user.name "kidseib"
    git config user.email "kidseib@users.noreply.github.com"

    git add addon tools
    git commit -q -m "feat: the sidewalk A-board advertises one line a day" \
        -m "Each shop day two chalkable lines are offered from the stock actually on the shelves; chalking one pays its data-banded lift on every sale of that category for the rest of the day (8-16%, bulk lines more than gems) and shortens the wait for the next customer by about 14%, because advertising is footfall rather than assortment. The lift and the pair are hashed from the date, so a reload cannot reroll them, and the save keeps only { day, key } - no number to drift. New Data/Board.lua and Modules/Board.lua, the lift in Negotiation.completeSale (flat wager settlements ignore it, like the request bonus), the arrival multiplier inside Shop.ArrivalInterval (no second scheduler), an additive sanitized db.shop.board, the dashboard board row with tooltips, the in-window A-board note, six new headless tests (101 total) and a UI-smoke attempt that chalks from the real dashboard row and checks the sale pays it."

    git add CHANGELOG.md TODO.md PROGRESS.md README.md
    git commit -q -m "docs: roadmap, changelog and test notes for the A-board" \
        -m "Marks plan item 4 shipped in the ordered ten-feature roadmap with what remains, and records the design reasoning (why the board is a player choice and not a second daily request, why advertising is footfall after the assortment-bias version measured at -7.7% revenue, why the numbers are deterministic, what the save keeps), the unchanged baseline sims plus the board-on/board-off probe, the test results and the known gaps."

    git rm -r -q .github/scripts
    git rm -q .github/workflows/apply-iter8.yml
    git commit -q -m "chore: remove iteration 8 delivery scaffolding"

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
        commit -q -m "chore: iteration 8 delivery report (failure)"
    git push origin HEAD:refinement-polish
fi

exit "$fail"
