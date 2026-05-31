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

# check_ratchet_test.sh
#
# Unit tests for the check_ratchet.sh linter script.
# It creates various valid and invalid mock workflows and asserts that the linter
# behaves correctly (passes on valid inputs, fails and reports errors on invalid inputs).

set -euo pipefail

# Locate the script under test portably (works on macOS and Linux)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
readonly SCRIPT_DIR
readonly SCRIPT_UNDER_TEST="${SCRIPT_DIR}/check_ratchet.sh"

# Temporary directory for mock files
TEST_TEMP_DIR=$(mktemp -d)
readonly TEST_TEMP_DIR

# Clean up temporary directory on exit
cleanup() {
  rm -rf "${TEST_TEMP_DIR}"
}
trap cleanup EXIT

# Test Case 1: Valid inputs should pass (Exit code 0)
test_valid_inputs() {
  echo "Running test: test_valid_inputs..."
  
  # Create a temporary subdir for this test to isolate it
  local case_dir="${TEST_TEMP_DIR}/valid"
  mkdir -p "${case_dir}"
  
  echo "
name: 'valid-workflow'
jobs:
  test:
    runs-on: 'ubuntu-latest'
    steps:
      - uses: 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' # ratchet:actions/checkout@v4
      - uses: './.github/actions/lint-java'
      - uses: 'actions/checkout@v4' # ratchet:exclude
" > "${case_dir}/valid.yml"

  # Run linter on this subdir
  local output
  if ! output=$("${SCRIPT_UNDER_TEST}" "${case_dir}" 2>&1); then
    echo "❌ FAILED: Valid inputs caused a failure!"
    echo "Output:"
    echo "${output}"
    return 1
  fi

  if [[ "${output}" != *"All ratchet comments are valid."* ]]; then
    echo "❌ FAILED: Missing success message!"
    echo "Output:"
    echo "${output}"
    return 1
  fi

  echo "✅ PASSED"
  return 0
}

# Test Case 2: Invalid inputs should fail (Exit code 1) and report specific errors
test_invalid_inputs() {
  echo "Running test: test_invalid_inputs..."
  
  local case_dir="${TEST_TEMP_DIR}/invalid"
  mkdir -p "${case_dir}"
  
  # 1. Pinned but missing comment (Line 7)
  # 2. Unpinned and no exclude (Line 9)
  # 3. Mismatched comment action (Line 11)
  echo "
name: 'invalid-workflow'
jobs:
  test:
    runs-on: 'ubuntu-latest'
    steps:
      - uses: 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683'
      
      - uses: 'actions/checkout@v4'
      
      - uses: 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' # ratchet:actions/setup-node@v4
" > "${case_dir}/invalid.yml"

  local output
  local exit_code=0
  output=$("${SCRIPT_UNDER_TEST}" "${case_dir}" 2>&1) || exit_code=$?

  if [[ "${exit_code}" -ne 1 ]]; then
    echo "❌ FAILED: Expected exit code 1, got ${exit_code}"
    echo "Output:"
    echo "${output}"
    return 1
  fi

  # Verify specific error messages are printed with correct line numbers
  local err1="Pinned action 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' is missing a valid '# ratchet:actions/checkout@<version>' comment"
  local err2="Action 'actions/checkout@v4' is not pinned to a SHA and is not excluded via '# ratchet:exclude'"

  if [[ "${output}" != *"invalid.yml,line=7::${err1}"* ]]; then
    echo "❌ FAILED: Missing or incorrect error for Case 1 (line 7)!"
    echo "Output:"
    echo "${output}"
    return 1
  fi

  if [[ "${output}" != *"invalid.yml,line=9::${err2}"* ]]; then
    echo "❌ FAILED: Missing or incorrect error for Case 2 (line 9)!"
    echo "Output:"
    echo "${output}"
    return 1
  fi

  if [[ "${output}" != *"invalid.yml,line=11::${err1}"* ]]; then
    echo "❌ FAILED: Missing or incorrect error for Case 3 (line 11)!"
    echo "Output:"
    echo "${output}"
    return 1
  fi

  echo "✅ PASSED"
  return 0
}

# Run all tests
main() {
  test_valid_inputs
  test_invalid_inputs
  echo "All unit tests passed successfully!"
}

main "$@"
