#!/usr/bin/env bash
# Run the plenary/busted specs headlessly. Each spec runs in its own nvim
# because plenary.busted exits after the first file.
#   ./tests/run.sh                # run everything
#   ./tests/run.sh tests/x_spec.lua  # run one file
set -uo pipefail
cd "$(dirname "$0")/.."

if [[ "$#" -gt 0 ]]; then
  files=("$@")
else
  files=(tests/*_spec.lua)
fi

failed=0
for file in "${files[@]}"; do
  echo "===== $file ====="
  if ! nvim --headless -u tests/minimal_init.lua -l tests/runner.lua "$file"; then
    echo "FAILED: $file"
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
echo ""
echo "All specs passed."
