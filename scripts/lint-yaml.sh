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

# Ensure yamllint is installed.
if ! command -v yamllint &> /dev/null; then
  echo "Error: yamllint is not installed." >&2
  echo "Please install it: pip install yamllint" >&2
  exit 1
fi

# Parse arguments
CONFIG=""
FILES_OR_DIRS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config)
      CONFIG="$2"
      shift 2
      ;;
    *)
      FILES_OR_DIRS+=("$1")
      shift
      ;;
  esac
done

# Determine files to lint.
files=()
if [[ ${#FILES_OR_DIRS[@]} -gt 0 ]]; then
  for arg in "${FILES_OR_DIRS[@]}"; do
    if [[ -f "${arg}" ]]; then
      # Ensure it is a YAML file
      if [[ "${arg}" =~ \.(yaml|yml)$ ]]; then
        files+=("${arg}")
      fi
    elif [[ -d "${arg}" ]]; then
      if git rev-parse --is-inside-work-tree &> /dev/null; then
        while IFS= read -r file; do
          if [[ -f "${file}" ]]; then
            files+=("${file}")
          fi
        done < <(git ls-files "${arg}" | grep -E '\.(yaml|yml)$' || true)
      else
        while IFS= read -r -d '' file; do
          files+=("${file}")
        done < <(find "${arg}" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0)
      fi
    fi
  done
else
  if git rev-parse --is-inside-work-tree &> /dev/null; then
    while IFS= read -r file; do
      if [[ -f "${file}" ]]; then
        files+=("${file}")
      fi
    done < <(git ls-files | grep -E '\.(yaml|yml)$')
  else
    echo "Not in a git repository and no files specified." >&2
    exit 1
  fi
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No YAML files found to lint."
  exit 0
fi

# Run yamllint.
EXTRA_ARGS=()
if [[ -n "${CONFIG}" ]]; then
  EXTRA_ARGS+=("-c" "${CONFIG}")
fi
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  EXTRA_ARGS+=("--format" "github")
fi

yamllint "${EXTRA_ARGS[@]}" "${files[@]}"
