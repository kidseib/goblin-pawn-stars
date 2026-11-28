#!/usr/bin/env bash
# TEMPORARY: applies the iteration-7 patch, runs the gate and commits the result.
# If any phase fails it publishes this report to the branch instead, because
# Actions logs are not readable without an authenticated session.
set -u

root="$(git rev-parse --show-toplevel)"
cd "$root"
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
    cat .github/scripts/iter7/p-0* > /tmp/iter7.patch.xz
    ls -l /tmp/iter7.patch.xz
    echo "8ec87667ef5e86fc6f66c1b953ebbf38a3c78801e8de3be21dab11306a8969c4  /tmp/iter7.patch.xz" | sha256sum -c -
    xz -dc /tmp/iter7.patch.xz > /tmp/iter7.patch
    ls -l /tmp/iter7.patch
    echo "108c86f7ba5f9556dbc8ca03b26cac8bfcfcb52447ce075ac539cf84ec834f68  /tmp/iter7.patch" | sha256sum -c -
    git apply --check /tmp/iter7.patch
    git apply /tmp/iter7.patch
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

    git add addon tools
    git commit -q -m "feat: double-or-nothing wager for the desperate buyer" \
        -m "The desperate archetype can put a flip on the table: win and they pay the most they would ever pay, lose and they pay 80% of the safe offer and the shop loses 2 standing. Odds are stated in the negotiation window and solved backwards from a ~94% edge over accepting, with the prize capped at twice the safe offer so it can never be free money. One wager per customer, remembered on the customer record the save already carries, and the sale still completes through completeSale so only a real unit leaves the shelves." \
        -m "New Data/Gamble.lua and Modules/Gamble.lua, the wager branch in Negotiation, a button plus tooltip and hint in the negotiation window, a sanitized customer.gambled flag in Persist.cleanCustomer, six new headless tests (95 total) and a UI-smoke attempt covering the button, the stated odds and the payout."

    git add CHANGELOG.md TODO.md PROGRESS.md README.md
    git commit -q -m "docs: roadmap, changelog and test notes for the wager" \
        -m "Marks plan item 3 shipped inside the ordered ten-feature roadmap and records the design reasoning (why the edge is negative, why the prize is capped, why the loss is reputation and not gold, why the once-per-customer flag rides on the customer record), the benchmark numbers and the known gaps."

    git rm -r -q .github/scripts
    git rm -q .github/workflows/apply-iter7.yml
    git commit -q -m "chore: remove iteration 7 delivery scaffolding"

    git push origin HEAD:refinement-polish
}

say "node=$(node -v 2>&1) xz=$(command -v xz 2>&1) bash=$BASH_VERSION"
say "head=$(git rev-parse --short HEAD)"

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
        commit -q -m "chore: iteration 7 delivery report (failure)"
    git push origin HEAD:refinement-polish
fi

exit "$fail"
