# Multi-approvers GitHub Action

Use this action to require two internal approvers for pull requests originating
from an external user. This prevents internal users from creating "sock puppet"
accounts and approving their own pull requests with their internal accounts.

Internal users are users that are in the given GitHub team. External users are
all other users.

This action requires a token with at least members:read, pull_requests:read, and
actions:write privledges.
[github-token-minter](https://github.com/abcxyz/github-token-minter) can be used
to generate this token in a workflow. Here's an example workflow YAML using this
action:

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
    runs-on: 'ubuntu-latest'
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
```

Here's another example using a stored secret to get the token:

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
    runs-on: 'ubuntu-latest'
    steps:
      - name: 'Multi-approvers'
        uses: 'abcxyz/actions/.github/actions/multi-approvers'
        with:
          team: 'github-team-slug'
          token: '${{ secrets.MULTI_APPROVERS_TOKEN }}'
```

## Development

`npm install`: Downloads required node packages.

`npm run lint`: Displays lint errors.

`npm run format`: Fixes lint errors.

`npm run build`: Generates minimized versions of Javascript source code.
This MUST be run after making changes to code under the `src` directory.

`npm run test`: runs tests.
