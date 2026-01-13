# Multi-approvers GitHub Action

Use this action to require two internal approvers for pull requests originating
from an external user. This prevents internal users from creating "sock puppet"
accounts and approving their own pull requests with their internal accounts.

Internal users are users that are in the given GitHub team. External users are
all other users.

Additionally, the `user-id-allowlist` input can be used to exempt users from multi-approver requirements. This should be used for users who cannot be included in the GitHub team e.g. bots. Note that the `user-id-allowlist` input takes numeric user IDs, not the string logins.

This action requires a token with at least members:read, pull_requests:read, and
actions:write privledges.
[github-token-minter](https://github.com/abcxyz/github-token-minter) can be used
to generate this token in a workflow. Here's an example workflow YAML using this
action:

> [!NOTE]
> Workflows can be triggered by either `pull_request` or `pull_request_target`
> events.
>
> The `pull_request` event is strongly recommended as it comes with less
> security risks compared to `pull_request_target`.
>
> However, if your repository
>
> 1. Is public
> 1. AND Will receives PRs from from forks
> 1. AND Is using a stored secret
>
> then you should use `pull_request_target` to be able to access the stored
> secret.
>
> Before using `pull_request_target`, please read about the
> [potential security risks](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/).


```yaml
name: 'multi-approvers'

on:
  pull_request:
    types:
      - 'opened'
      - 'edited'
      - 'reopened'
      - 'synchronize'
      - 'ready_for_review'
      - 'review_requested'
      - 'review_request_removed'
  pull_request_review:
    types:
      - 'submitted'
      - 'dismissed'

permissions:
  actions: 'write'
  contents: 'read'
  id-token: 'write'
  pull-requests: 'read'

concurrency:
  group: '${{ github.workflow }}-${{ github.head_ref || github.ref }}'
  cancel-in-progress: true

jobs:
  multi-approvers:
    runs-on: 'self-hosted'
    steps:
      - name: 'Authenticate to Google Cloud'
        id: 'minty-auth'
        uses: 'google-github-actions/auth@6fc4af4b145ae7821d527454aa9bd537d1f2dc5f' # ratchet:google-github-actions/auth@v2
        with:
          create_credentials_file: false
          export_environment_variables: false
          workload_identity_provider: '${{ vars.TOKEN_MINTER_WIF_PROVIDER }}'
          service_account: '${{ vars.TOKEN_MINTER_WIF_SERVICE_ACCOUNT }}'
          token_format: 'id_token'
          id_token_audience: '${{ vars.TOKEN_MINTER_SERVICE_AUDIENCE }}'
          id_token_include_email: true

      - name: 'Mint Token'
        id: 'minty'
        uses: 'abcxyz/github-token-minter/.github/actions/minty@main' # ratchet:exclude
        with:
          id_token: '${{ steps.minty-auth.outputs.id_token }}'
          service_url: '${{ vars.TOKEN_MINTER_SERVICE_URL }}'
          requested_permissions: |-
            {
              "scope": "your-scope",
              "repositories": ["your-repository-name"],
              "permissions": {
                "actions": "write",
                "members": "read",
                "pull_requests": "read"
              }
            }

      - name: 'Multi-approvers'
        uses: 'abcxyz/actions/.github/actions/multi-approvers'
        with:
          team: 'github-team-slug'
          token: '${{ steps.minty.outputs.token }}'
          user-id-allowlist: '12345,67890'
```

Here's another example using a stored secret to get the token:

```yaml
name: 'multi-approvers'

on:
  pull_request[_target]:
    types:
      - 'opened'
      - 'edited'
      - 'reopened'
      - 'synchronize'
      - 'ready_for_review'
      - 'review_requested'
      - 'review_request_removed'
  pull_request_review:
    types:
      - 'submitted'
      - 'dismissed'

permissions:
  actions: 'write'
  contents: 'read'
  id-token: 'write'
  pull-requests: 'read'

concurrency:
  group: '${{ github.workflow }}-${{ github.head_ref || github.ref }}'
  cancel-in-progress: true

jobs:
  multi-approvers:
    runs-on: 'self-hosted'
    steps:
      - name: 'Multi-approvers'
        uses: 'abcxyz/actions/.github/actions/multi-approvers'
        with:
          team: 'github-team-slug'
          token: '${{ secrets.MULTI_APPROVERS_TOKEN }}'
          user-id-allowlist: '12345,67890'
```

## Development

`npm install`: Downloads required node packages.

`npm run lint`: Displays lint errors.

`npm run format`: Fixes lint errors.

`npm run build`: Generates minimized versions of Javascript source code.
This MUST be run after making changes to code under the `src` directory.

`npm run test`: runs tests.

## Caveats

It's a known limitation that the check may need to be manually re-triggered if this workflow is used as a part of rulesets.

This is because `pull_review_request` is not one of the [supported triggers](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#supported-event-triggers) in ruleset workflows.

See [relevant issue](https://github.com/abcxyz/actions/issues/83) for more details.