#!/usr/bin/env bash
# WeatherWatch capstone — build a clean git repo with a distinct "fix commit".
# Run on your Mac from inside the phase2-apigateway folder:  bash setup-repo.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building a clean git repo (removing any partial one first)"
rm -rf .git

git init -b main >/dev/null 2>&1 || { git init >/dev/null; git checkout -b main >/dev/null 2>&1 || true; }
git config user.name  "$(git config --global user.name  2>/dev/null || echo 'Subahan Talamarla')"
git config user.email "$(git config --global user.email 2>/dev/null || echo 'subahan0375@gmail.com')"

# main.tf must currently contain the throttling fix (it does)
grep -q 'default_route_settings' main.tf || { echo "ERROR: throttling block missing from main.tf"; exit 1; }

echo "==> Commit 1: the working capstone WITHOUT the fix (baseline)"
cp main.tf .main.fixed.bak
python3 - <<'PY'
s = open("main.tf").read().split("\n"); out = []; i = 0
while i < len(s):
    if s[i].strip().startswith("# FIX (self-review F2)"):
        if out and out[-1].strip() == "":
            out.pop()                        # drop blank line before the block
        while i < len(s) and s[i].rstrip() != "  }":
            i += 1                            # skip to default_route_settings close
        i += 1                                # skip that "  }" too
        continue
    out.append(s[i]); i += 1
open("main.tf", "w").write("\n".join(out))
PY
git add -A
git commit -q -m "Phase 2: public API Gateway + Lambda + Secrets Manager + on-demand DynamoDB"

echo "==> Commit 2: THE FIX (restore the throttling block)"
mv .main.fixed.bak main.tf
git add main.tf
git commit -q -m "Fix (self-review F2): throttle public API Gateway route (10 rps, burst 5) -> HTTP 429 past limit"

echo
echo "==> Local history:"
git log --oneline
echo
cat <<'EOF'
================  NEXT: create the GitHub repo and push  ================

  Option A — GitHub CLI (if you have `gh`):
    gh repo create weatherwatch-capstone --public --source=. --remote=origin --push

  Option B — manual:
    1) Create an EMPTY repo named  weatherwatch-capstone  at https://github.com/new
       (do NOT add a README or .gitignore)
    2) git remote add origin https://github.com/<YOU>/weatherwatch-capstone.git
    3) git push -u origin main

================  YOUR TWO SUBMISSION LINKS  ================

  1) diagram & decisions:
     https://github.com/<YOU>/weatherwatch-capstone/blob/main/01-architecture-and-decisions.pdf

  2) fix commit:  run  ->  git log -1 --format=%H   (copy the hash)
     https://github.com/<YOU>/weatherwatch-capstone/commit/<HASH>
EOF
