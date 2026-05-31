#!/usr/bin/env bash
# Copyright 2026 The Authors (see AUTHORS file)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# shellcheck disable=SC2312
set -euo pipefail

# Ensure shellcheck is installed.
if ! command -v shellcheck &> /dev/null; then
  echo "Error: shellcheck is not installed." >&2
  echo "Please install it: https://github.com/koalaman/shellcheck#installing" >&2
  exit 1
fi

# Ensure file utility is installed.
if ! command -v file &> /dev/null; then
  echo "Error: 'file' utility is not installed." >&2
  exit 1
fi

# Determine files to lint.
files=()
if [[ $# -gt 0 ]]; then
  # If arguments are provided, use them. Expand directories if found.
  for arg in "$@"; do
    if [[ -f "${arg}" ]]; then
      files+=("${arg}")
    elif [[ -d "${arg}" ]]; then
      if git rev-parse --is-inside-work-tree &> /dev/null; then
        while IFS= read -r file; do
          if [[ -f "${file}" ]]; then
            if file --mime-type "${file}" | grep -q "text/x-shellscript"; then
              files+=("${file}")
            fi
          fi
        done < <(git ls-files "${arg}" | grep -E '^([^.]+|.*\.(sh|zsh|bash))$' || true)
      else
        while IFS= read -r -d '' file; do
          if file --mime-type "${file}" | grep -q "text/x-shellscript"; then
            files+=("${file}")
          fi
        done < <(find "${arg}" -type f -print0)
      fi
    fi
  done
else
  # Find all shell scripts in the git repo.
  if git rev-parse --is-inside-work-tree &> /dev/null; then
    # Find all bash scripts even if they don't have an explicit extension.
    # Using a while loop to handle spaces in filenames safely.
    while IFS= read -r file; do
      if [[ -f "${file}" ]]; then
        # Check mime type to see if it is a shell script
        if file --mime-type "${file}" | grep -q "text/x-shellscript"; then
          files+=("${file}")
        fi
      fi
    done < <(git ls-files | grep -E '^([^.]+|.*\.(sh|zsh|bash))$')
  else
    echo "Not in a git repository and no files specified." >&2
    exit 1
  fi
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No shell files found to lint."
  exit 0
fi

# Run shellcheck.
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  # In CI, use GCC format.
  # Note that only warning and error severity show up in the github files page.
  # So we replace 'style' and 'note' with 'warning' to make it show up.
  shellcheck \
    --check-sourced \
    --enable=all \
    --severity=style \
    --format=gcc \
    --color=never "${files[@]}" | sed -e 's/note:/warning:/g' -e 's/style:/warning:/g'
else
  # Locally, use default format with colors
  shellcheck \
    --check-sourced \
    --enable=all \
    --severity=style \
    "${files[@]}"
fi
