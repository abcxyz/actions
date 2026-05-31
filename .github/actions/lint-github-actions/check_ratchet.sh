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

# check_ratchet.sh
#
# This script verifies that all GitHub Actions 'uses' statements in the repository's
# workflows and composite actions are securely pinned to a commit SHA and annotated
# with a matching '# ratchet:' comment showing the original version tag (or explicitly
# excluded via '# ratchet:exclude').
#
# This ensures that external dependencies are immutable (for security) and maintainable
# by automated tools like Renovate.

set -euo pipefail

# Static regex patterns (Read-only globals)
# Group 1 is optional leading hyphen, Group 2 is the action reference
readonly PATTERN_USES="^(-[[:space:]]*)?uses:[[:space:]]*['\"]?([^'\"]+)['\"]?"
readonly PATTERN_VARIABLE="\$\{\{"
readonly PATTERN_LOCAL="^\./"
readonly PATTERN_EXCLUDE="#[[:space:]]*ratchet:exclude"
readonly PATTERN_SHA="@([[:alnum:]]{40})$"

# Lints a single workflow or action file for correct Ratchet annotations.
# Arguments:
#   $1: Path to the YAML file to check.
# Returns:
#   0 if valid, 1 if errors were found.
lint_file() {
  local file="${1}"
  local exit_code=0
  local line_num=0
  local line
  local trimmed_line
  local temp
  local action
  local action_name
  local pattern_ratchet


  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_num=$((line_num + 1))
    
    # Trim leading and trailing whitespace using pure Bash (no subprocess)
    temp="${line#"${line%%[![:space:]]*}"}"
    trimmed_line="${temp%"${temp##*[![:space:]]}"}"
    
    # Check for "uses:"
    if [[ "${trimmed_line}" =~ ${PATTERN_USES} ]]; then
      action="${BASH_REMATCH[2]}"
      
      # Skip dynamic uses (containing variables)
      if [[ "${action}" =~ ${PATTERN_VARIABLE} ]]; then
        continue
      fi
      
      # Check if local action
      if [[ "${action}" =~ ${PATTERN_LOCAL} ]]; then
        # Local actions are inherently safe, no pinning required
        continue
      fi
      
      # External action
      if [[ "${action}" =~ ${PATTERN_SHA} ]]; then
        # Extract action name using pure Bash (no subprocess)
        action_name="${action%@*}"
        
        if [[ "${trimmed_line}" =~ ${PATTERN_EXCLUDE} ]]; then
          continue
        fi
        
        # Expected: # ratchet:<action_name>@<version>
        pattern_ratchet="#[[:space:]]*ratchet:${action_name}@([^[:space:]]+)"
        
        if [[ ! "${trimmed_line}" =~ ${pattern_ratchet} ]]; then
          echo "::error file=${file},line=${line_num}::Pinned action '${action}' is missing a valid '# ratchet:${action_name}@<version>' comment"
          exit_code=1
        fi
      else
        # Unpinned action
        if [[ ! "${trimmed_line}" =~ ${PATTERN_EXCLUDE} ]]; then
          echo "::error file=${file},line=${line_num}::Action '${action}' is not pinned to a SHA and is not excluded via '# ratchet:exclude'"
          exit_code=1
        fi
      fi
    fi
  done < "${file}"

  return "${exit_code}"
}

main() {
  local global_exit_code=0
  local file
  local find_pid
  local search_dirs=(".github/workflows" ".github/actions")

  # Allow overriding search targets for unit testing
  if [[ $# -gt 0 ]]; then
    search_dirs=("$@")
  fi

  # Open find process substitution on file descriptor 3 to safely capture its PID
  # and avoid silent pass bugs if find fails (SC2312).
  # shellcheck disable=SC2312
  exec 3< <(find "${search_dirs[@]}" \
    -not -path "*/node_modules/*" \
    -type f \( -name "*.yml" -o -name "*.yaml" \) \
    -print0)
  find_pid=$!

  while IFS= read -r -d '' file <&3; do
    # It is safe to disable set -e inside lint_file because it handles its own exit codes.
    # shellcheck disable=SC2310
    if ! lint_file "${file}"; then
      global_exit_code=1
    fi
  done

  # Close file descriptor 3
  exec 3<&-

  # Wait for find process to ensure it completed successfully (prevents silent passes)
  wait "${find_pid}"

  if [[ "${global_exit_code}" -eq 0 ]]; then
    echo "All ratchet comments are valid."
  fi

  return "${global_exit_code}"
}

main "$@"
