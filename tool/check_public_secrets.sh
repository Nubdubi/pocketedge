#!/usr/bin/env bash
set -euo pipefail

# This is a lightweight guard for accidental commits. It is not a replacement
# for a full secret-management system or a security review.
patterns=(
  '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
  'gh[pousr]_[A-Za-z0-9_]{30,}'
  'sk_live_[A-Za-z0-9]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{20,}'
  'cloudflared[^[:cntrl:]]*(credentials-file|tunnel token)'
)

for pattern in "${patterns[@]}"; do
  if git grep --cached -n -I -E -e "$pattern" -- ':!tool/check_public_secrets.sh'; then
    echo "Potential secret detected: $pattern" >&2
    exit 1
  fi
done

echo "No known secret patterns found in tracked files."
