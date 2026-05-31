# Local Development & Testing Guidelines

This document outlines how to run linters and checks locally to ensure your changes pass CI before you push.

## Standalone Linter Scripts

The core linting logic is defined in standalone scripts under the `scripts/` directory, which serve as the single source of truth and are used both locally and in GitHub Actions.

### 1. Shell Linter (`scripts/lint-shell.sh`)
Lints all shell scripts in the repository using `shellcheck`.

*   **Prerequisites:** Install `shellcheck` (e.g., `brew install shellcheck` or `sudo apt-get install shellcheck`).
*   **Run on all files:**
    ```bash
    ./scripts/lint-shell.sh
    ```
*   **Run on specific files or directories:**
    ```bash
    ./scripts/lint-shell.sh path/to/file.sh path/to/dir/
    ```

### 2. YAML Linter (`scripts/lint-yaml.sh`)
Lints YAML files against the repository's `.yamllint.yml` configuration.

*   **Prerequisites:** Install `yamllint` (e.g., `pip install yamllint` or `brew install yamllint`).
*   **Run on all files:**
    ```bash
    ./scripts/lint-yaml.sh
    ```
*   **Run on specific files or directories:**
    ```bash
    ./scripts/lint-yaml.sh path/to/file.yml path/to/dir/
    ```
*   **Run with custom config:**
    ```bash
    ./scripts/lint-yaml.sh -c path/to/config.yml [files...]
    ```

---

## Automating Local Workflows

To make linting a seamless part of your development workflow, you can use one of the following integrations.

### Option A: Git Hooks via `pre-commit` (Recommended)

We use the `pre-commit` framework to automatically run linters on staged files before every commit.

1.  **Install `pre-commit` globally:** (e.g., `brew install pre-commit` on macOS, `sudo apt install pre-commit` on Ubuntu, or `pipx install pre-commit`).
2.  **Install the Git hooks:**
    Run this command in the root of the repository:
    ```bash
    pre-commit install
    ```
3.  **Usage:**
    *   Hooks will now run automatically on `git commit` only on the files you changed.
    *   *Note:* Since our hooks call local scripts, they run in your current shell context. If you installed `yamllint` or `shellcheck` inside a project `venv`, you must have that `venv` active when committing so they can be found.
    *   To run all checks on all files manually:
        ```bash
        pre-commit run --all-files
        ```

### Option B: Jujutsu Native Integration (`jj fix`)

If you use Jujutsu (`jj`), you can integrate these linters into the `jj fix` command. Add the following to your Jujutsu configuration (typically `~/.config/jj/config.toml` or `.jj/repo/config.toml` for repo-specific):

```toml
[fix.tools.shellcheck]
command = ["./scripts/lint-shell.sh"]
args = ["$path"]
patterns = ["glob:**/*.{sh,zsh,bash}"]

[fix.tools.yamllint]
command = ["./scripts/lint-yaml.sh"]
args = ["$path"]
patterns = ["glob:**/*.{yaml,yml}"]

[fix.tools.check-ratchet]
command = [".github/actions/lint-github-actions/check_ratchet.sh"]
args = ["$path"]
patterns = ["glob:.github/{workflows,actions}/**/*.{yaml,yml}"]
```

Once configured, you can run `jj fix` to lint your working copy changes on demand.

### Option C: IDE Integration (VS Code)

To get real-time feedback in your editor as you type, you can install the recommended workspace extensions.

When you open this workspace in **VS Code**, it will read `.vscode/extensions.json` and you should be automatically prompted to install the recommended extensions:

1.  **ShellCheck** (`timonwong.shellcheck`): Highlights shell scripting errors inline using the `shellcheck` binary on your system.
2.  **YAML** (`redhat.vscode-yaml`): Provides general YAML syntax validation and schema support.
3.  **YamlLint** (`lyz-code.yamllint`): Enforces strict styling rules by automatically reading the repository's local `.yamllint.yml` file.
