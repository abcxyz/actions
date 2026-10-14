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

# Usage: resolve-release-mirror.sh <url> <download-dir>
#
# On GitHub Enterprise Server, release assets from github.com are often
# mirrored onto the same-named repository of the instance. Fetching them from
# the instance avoids github.com rate limits on shared-egress runners.
#
# If <url> is a github.com release asset
# (https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>[?query])
# and the workflow runs on a different GitHub host (GITHUB_SERVER_URL), this
# downloads ${GITHUB_SERVER_URL}/<owner>/<repo>/releases/download/<tag>/<asset>
# into <download-dir> and prints the local path (plus the original query).
# Otherwise, or if the instance has no copy, it prints <url> unchanged so the
# caller falls back to github.com.
#
# Env:
#   GITHUB_SERVER_URL      set by the runner
#   GITHUB_TOKEN           optional; sent only to GITHUB_SERVER_URL
#   RELEASE_MIRROR_LOOKUP  set to "false" to disable the lookup

set -euo pipefail

readonly url="${1:?usage: resolve-release-mirror.sh <url> <download-dir>}"
readonly dest="${2:?usage: resolve-release-mirror.sh <url> <download-dir>}"
readonly server="${GITHUB_SERVER_URL:-https://github.com}"
readonly re='^https://github\.com/([^/]+/[^/]+/releases/download/[^?]+)(\?.*)?$'

if [[ "${RELEASE_MIRROR_LOOKUP:-true}" != "true" ||
  "${server%/}" == "https://github.com" ||
  ! "${url}" =~ ${re} ]]; then
  echo "${url}"
  exit 0
fi

readonly path="${BASH_REMATCH[1]}"
readonly query="${BASH_REMATCH[2]}"
readonly mirror="${server%/}/${path}"

mkdir -p "${dest}"
file="${dest}/$(basename "${path}")"

auth=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  # curl drops this header if a redirect leaves the server's host.
  auth=(-H "Authorization: token ${GITHUB_TOKEN}")
fi

# A login or error page can come back as 200 after redirects, so require a
# non-HTML body served from the instance or its asset storage.
if meta="$(curl -sSfL --retry 2 --max-time 300 ${auth[@]+"${auth[@]}"} \
  -o "${file}" -w '%{content_type} %{url_effective}' "${mirror}" 2>/dev/null)" &&
  [[ "${meta%% *}" != text/html* ]] &&
  effective="${meta#* }" && host="${effective#*://}" && host="${host%%/*}" &&
  [[ "${host}" != login.* ]] &&
  [[ -s "${file}" ]]; then
  echo "Using ${mirror}" >&2
  echo "${file}${query}"
else
  rm -f "${file}"
  echo "No copy at ${mirror}; using ${url}" >&2
  echo "${url}"
fi
