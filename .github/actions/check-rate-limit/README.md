# Check Rate Limit GitHub Action

Reports the REST API rate limit budget for a token and, optionally, whether
there is enough of it left to proceed. Works against github.com and GitHub
Enterprise Server.

`GET /rate_limit` does not itself consume quota, so this is free to run.

Use it to keep a long, non-critical workflow from draining a budget that a
critical one shares, and to stop a run that cannot finish rather than have it
die partway through.

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `github_token` | `${{ github.token }}` | The token whose budget is checked. Budgets are per account, so this must be the token the work will actually spend. |
| `api_url` | `${{ github.api_url }}` | REST API base URL. The default resolves to `https://api.github.com` on github.com and `https://HOST/api/v3` on GHES. |
| `resource` | `core` | Which budget: `core`, `graphql`, `search`, `code_search`, ... |
| `threshold` | `0` | Requests that must remain for `proceed` to be true. `0` always proceeds. |
| `fail_below_threshold` | `false` | Fail the step below threshold instead of only reporting it. |

## Outputs

The budget outputs describe the bucket named by `resource`.

| Output | Description |
| --- | --- |
| `proceed` | `true` when `remaining` is at or above `threshold`. |
| `remaining` | Requests left in the window. |
| `limit` | Requests allowed per window. |
| `used` | Requests spent in the window. |
| `reset` | Epoch seconds at which the window resets. |
| `reset_in_seconds` | Seconds until the window resets. |
| `resources` | Every bucket the instance reports, as JSON, each with `reset_in_seconds` added. `{}` when rate limiting is off. |
| `enabled` | `false` when the instance has rate limiting turned off. |

> [!IMPORTANT]
> Window length differs per bucket and the payload does not say which is which:
> an hour for `core`, `graphql` and `scim`, but 60 seconds for `search`,
> `code_search`, `source_import`, `dependency_*` and `code_scanning_autofix`.
> Use `reset_in_seconds` rather than assuming an hour. `graphql` counts points,
> not requests. `core` is 5,000/hour for a PAT and 15,000/hour on GHES, but only
> 1,000/hour per repository for `GITHUB_TOKEN`.

> [!NOTE]
> Rate limiting is off by default on GitHub Enterprise Server, where
> `GET /rate_limit` then answers 404. That is reported as `enabled: false` with
> `proceed: true` and empty budget outputs, not as an error: there is no budget
> to run out of. Secondary rate limits (concurrency, content creation bursts)
> are not in `/rate_limit` and still apply.

## Gating on the result

`proceed` is an output, not a hard stop, so the caller decides what to skip.

```yaml
jobs:
  check:
    runs-on: 'ubuntu-latest'
    outputs:
      proceed: '${{ steps.check.outputs.proceed }}'
    steps:
      - name: 'Check Rate Limit'
        id: 'check'
        uses: 'abcxyz/actions/.github/actions/check-rate-limit@main'
        with:
          github_token: '${{ secrets.SHARED_ACCOUNT_TOKEN }}'
          threshold: '2000'

  expensive-sweep:
    runs-on: 'ubuntu-latest'
    needs:
      - 'check'
    if: |-
      needs.check.outputs.proceed == 'true'
    steps:
      - name: 'Sweep'
        shell: 'bash'
        run: 'echo "there is budget to spend"'
```

To stop the run outright instead, set `fail_below_threshold: true`.

To size the work to the budget rather than skip it, read `remaining` and plan
against it:

```yaml
      - name: 'Check Rate Limit'
        id: 'check'
        uses: 'abcxyz/actions/.github/actions/check-rate-limit@main'

      - name: 'Plan'
        shell: 'bash'
        env:
          REMAINING: '${{ steps.check.outputs.remaining }}'
        run: |-
          echo "targets=$(( (REMAINING - 2000) / 3 ))" >> "${GITHUB_OUTPUT}"
```

## Other buckets

Set `resource` to gate on something other than `core`. Search is the usual
second one, and it is far tighter: 30 requests per *minute*.

```yaml
      - name: 'Check Search Rate Limit'
        id: 'search'
        uses: 'abcxyz/actions/.github/actions/check-rate-limit@main'
        with:
          resource: 'search'
          threshold: '10'
```

Each step gates on one bucket. To gate on several, use a step per bucket, or
read them all out of `resources`, which one call already collected:

```yaml
      - name: 'Plan'
        shell: 'bash'
        env:
          RESOURCES: '${{ steps.check.outputs.resources }}'
        run: |-
          jq -r 'to_entries[] | "\(.key) \(.value.remaining)/\(.value.limit)"' \
            <<< "${RESOURCES}"
```

## Testing

`.github/workflows/.check-rate-limit-test.yml` runs the action against the live
API and against `testdata/mock_api.py`, a stdlib-only stand-in that serves
budgets a live API will not reproduce on demand. Scenarios are selected by path
prefix (`/normal`, `/low`, `/disabled`, `/intercepted`), which is just the
`api_url` input, so one server covers every case.
