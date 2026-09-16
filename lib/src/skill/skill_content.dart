/// Embedded default SKILL.md content for Flutter Version Bumper.
const String defaultSkillContent = '''---
name: flutter-version-bumper
description: Automates version management, Semantic Versioning (SemVer) bumping, CHANGELOG.md updating, and Git tagging/pushing for Flutter and Dart projects using the FVB CLI tool. Use when the user requests to bump or update versions in pubspec.yaml, manage pre-releases (alpha, beta, rc), promote pre-releases to stable, update CHANGELOG.md, configure git hooks, or automate git release commits and tags.
---

# Flutter Version Bumper (FVB) Agent Skill

A comprehensive runbook and procedural guide for AI Coding Agents to reliably manage versions, bump Semantic Versioning (SemVer) numbers, maintain release notes in `CHANGELOG.md`, and execute Git release automation in Flutter and Dart projects.

## Contents
- [When to Activate This Skill](#when-to-activate-this-skill)
- [Prerequisites & CLI Invocation](#prerequisites--cli-invocation)
- [Agent Execution Workflow](#agent-execution-workflow)
- [Command Recipes](#command-recipes)
  - [1. Standard SemVer Bumping](#1-standard-semver-bumping)
  - [2. Pre-Release Lifecycle & Promotion](#2-pre-release-lifecycle--promotion)
  - [3. Explicit Versions & Build Numbers](#3-explicit-versions--build-numbers)
  - [4. Automated CHANGELOG Maintenance](#4-automated-changelog-maintenance)
  - [5. Git Release Automation](#5-git-release-automation)
  - [6. Git Hooks & Agent Skill Management](#6-git-hooks--agent-skill-management)
- [Machine-Readable JSON Output](#machine-readable-json-output)
- [POSIX Exit Codes & Error Recovery](#posix-exit-codes--error-recovery)
- [Configuration Reference (.fvb.yaml)](#configuration-reference-fvbyaml)
- [Agent Safety Rules](#agent-safety-rules)

---

## When to Activate This Skill

Activate this skill whenever:
* The user asks to bump, increment, or set the version in a Flutter or Dart project's `pubspec.yaml`.
* Managing releases: major (breaking), minor (features), patch (fixes), build-only, or pre-releases (`alpha`, `beta`, `rc`).
* Promoting an existing pre-release to a stable production release (`--release` / `--promote`).
* Adding structured release notes to `CHANGELOG.md`.
* Automating Git commits, annotated tags, and remote pushes for release builds.
* Setting up Git pre-commit or pre-push hooks to enforce valid version strings.

---

## Prerequisites & CLI Invocation

Agents should check whether `fvb` is available in PATH, or invoke it directly via the Dart runtime:

```bash
# Check global installation
fvb --help

# Or invoke directly within the repository:
dart run bin/fvb.dart --help
```

If not activated globally, agents can run:
```bash
dart pub global activate --source git https://github.com/chamod-rashmith/flutter-version-bumper
# Or activate from pub.dev:
dart pub global activate flutter_version_bumper
```

---

## Agent Execution Workflow

Follow this reliable 4-step loop when executing version tasks:

```
[1. Inspect/Detect] ──> [2. Dry-Run Preview] ──> [3. Apply Version Change] ──> [4. Verify Result]
```

1. **Inspect**: Check current `pubspec.yaml` version and Git working tree status (`git status --porcelain`).
2. **Dry-Run Preview**: Run with `-d` (`--dry-run`) and `--json` to preview planned mutations without touching the filesystem.
3. **Apply**: Run `fvb` with the appropriate bump flags (`-b`, `--pre`, `--release`, etc.).
4. **Verify**: Inspect the process exit code (expect `0`) and review the updated `pubspec.yaml` or JSON payload.

---

## Command Recipes

### 1. Standard SemVer Bumping
* **Patch Release (bug fixes)**: `1.0.0+1` -> `1.0.1+2`
  ```bash
  fvb
  # or explicitly:
  fvb -b patch
  ```
* **Minor Release (backward-compatible features)**: `1.0.1+2` -> `1.1.0+3`
  ```bash
  fvb -b minor
  ```
* **Major Release (breaking changes)**: `1.1.0+3` -> `2.0.0+4`
  ```bash
  fvb -b major
  ```
* **Build-Number-Only Release (CI builds)**: `1.0.0+1` -> `1.0.0+2`
  ```bash
  fvb -b build
  ```

### 2. Pre-Release Lifecycle & Promotion
* **Start or Increment Beta Track**: `1.0.0+1` -> `1.0.1-beta.1+2`
  ```bash
  fvb --pre beta
  ```
* **Transition Pre-Release Track (e.g. Beta to RC)**: `1.0.1-beta.1+2` -> `1.0.1-rc.1+3`
  ```bash
  fvb --pre rc
  ```
* **Promote Pre-Release to Stable Release**: `1.0.1-rc.1+3` -> `1.0.1+4`
  ```bash
  fvb --release
  # or alias:
  fvb --promote
  ```

### 3. Explicit Versions & Build Numbers
* **Set Explicit Full Version**:
  ```bash
  fvb -s 2.0.0-beta.1+42
  ```
* **Explicit Build Number Override**:
  ```bash
  fvb -n 100
  ```
* **Preserve Current Build Number (no increment)**:
  ```bash
  fvb --keep-build
  ```
* **Strip Build Number Segment Entirely**:
  ```bash
  fvb --no-build
  ```

### 4. Automated CHANGELOG Maintenance
* **Prepend Version Section to CHANGELOG.md**:
  ```bash
  fvb -c --changelog-msg "Added authentication and dark mode features"
  ```
* **Custom CHANGELOG Path**:
  ```bash
  fvb -c --changelog-msg "Bug fixes" --path path/to/pubspec.yaml
  ```

### 5. Git Release Automation
* **Commit, Tag, and Push**:
  ```bash
  fvb -b minor -c --changelog-msg "Release v1.2.0" -g -t --git-push
  ```
* **Custom Commit Message & Tag Prefix**:
  ```bash
  fvb -g -t -m "release: v{version}" --tag-prefix "v"
  ```
* **Bypass Dirty Working Tree Check**:
  > [!WARNING]
  > FVB blocks Git commits if untracked/uncommitted changes exist in the working tree. Use `--allow-dirty` only if intentional.
  ```bash
  fvb -g --allow-dirty
  ```

### 6. Git Hooks & Agent Skill Management
* **Install Pre-Commit Hook**: Validates `pubspec.yaml` version before every commit.
  ```bash
  fvb --install-hook pre-commit
  ```
* **Install Agent Skill into Repository**:
  ```bash
  fvb --install-skill
  ```

---

## Machine-Readable JSON Output

Always append `--json` when invoking FVB programmatically from tool execution scripts.

```bash
fvb -b minor -c -g --json
```

**JSON Output Schema:**
```json
{
  "success": true,
  "previous_version": "1.2.0+3",
  "new_version": "1.3.0+4",
  "pubspec_path": "/workspace/pubspec.yaml",
  "dry_run": false,
  "changelog_updated": true,
  "git_committed": true,
  "git_tagged": false,
  "git_pushed": false
}
```

---

## POSIX Exit Codes & Error Recovery

FVB follows POSIX exit codes from `package:io` (`ExitCode`). Agents should inspect exit codes to diagnose issues:

| Exit Code | Constant | Meaning & Agent Recovery Strategy |
|:---:|:---|:---|
| **0** | `ExitCode.success` | Operation succeeded. |
| **64** | `ExitCode.usage` | Invalid CLI arguments (e.g. conflicting flags like `--release` with `-s`, negative build numbers). Review argument syntax. |
| **65** | `ExitCode.data` | Version string format error in `pubspec.yaml` or `-s`. Ensure versions conform to `X.Y.Z` or `X.Y.Z+W`. |
| **74** | `ExitCode.ioError` | `pubspec.yaml` not found or filesystem permission error. Check `--path` argument. |
| **78** | `ExitCode.config` | Malformed YAML in `.fvb.yaml` or `--config-path`. Fix YAML syntax. |
| **70** | `ExitCode.software` | Unexpected internal runtime failure. Check stderr for stack trace. |

---

## Configuration Reference (.fvb.yaml)

Teams can configure persistent defaults in `.fvb.yaml` (or inside the `fvb:` section of `pubspec.yaml`):

```yaml
fvb:
  bump: patch               # Default bump segment: major, minor, patch, build
  keep-build: false         # Whether to preserve build number
  no-build: false           # Whether to remove build number
  git: true                 # Automatically commit pubspec changes
  git-tag: true             # Automatically create git tag
  git-push: false           # Automatically push to origin
  allow-dirty: false        # Allow committing with dirty working tree
  commit-msg: "chore: bump version to {version}"
  tag-prefix: "v"           # Git tag prefix
  changelog: true           # Automatically update CHANGELOG.md
  changelog-path: "CHANGELOG.md"
  changelog-msg: "Release {version}"
```

---

## Agent Safety Rules

1. **Always Preview with `--dry-run` (`-d`)**:
   When operating autonomously or when unsure of repository state, run `fvb -d --json` first to confirm the version transitions.
2. **Never Force Commits Blindly**:
   If Git aborts with a dirty working tree warning, inspect `git status` first rather than immediately passing `--allow-dirty`.
3. **Parse Machine-Readable JSON**:
   Use `--json` and `-q` (`--quiet`) for silent, deterministic output parsing without ANSI escape codes.
''';
