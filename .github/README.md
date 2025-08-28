# Workflows and actions

You will find all reusable `actions` and `workflows` in their respective
subfolders. Unfortunately, there is no way to distinguish workflows that only
run on this repository from ones that are intended to run elsewhere via
`workflow_call`. As such, we have made the decision to prefix workflows that run
on this repository with a `.`. Workflows intended to be run as reusable
workflows in other repositories will not be prefixed with `.` and additionally
will only have the `workflow_call` trigger.

Example:
* `.github/workflows/maybe-build-docker.yml` - The reusable workflow for
  building docker images.
* `.github/workflows/.ci-docker-test.yml` - The workflow that executes the
  above workflow in this repository as a test.

> [!NOTE]
> We cannot put reusable workflows in any other location.
> https://github.com/orgs/community/discussions/10773

## Exception to the rule

The one exception to the rule is workflows that will be used as required
workflows via organization rulesets. Which are the following workflows:

* `.github/workflows/lint.yml` - A default linter for every repo.
* `.github/workflows/abc-checks.yml` - A default compliance/PR checker for every repo.
