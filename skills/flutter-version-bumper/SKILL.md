---
name: flutter-version-bumper
description: Automates version management, Semantic Versioning (SemVer) bumping, CHANGELOG.md updating, and Git tagging/pushing for Flutter and Dart projects using the FVB CLI tool.
---

# Flutter Version Bumper (FVB) Agent Skill

This skill provides step-by-step instructions for AI Coding Agents to manage versioning, update `pubspec.yaml`, generate `CHANGELOG.md` entries, and execute Git release automation for Flutter/Dart applications and packages.

---

## When to Activate This Skill

Activate this skill when:
- The user requests to bump or update the version of a Flutter or Dart project.
- Preparing a new release (major, minor, patch, build, or pre-release).
- Updating release notes in `CHANGELOG.md`.
- Setting up pre-commit Git hooks for version checking.
- Automating Git tagging or pushing release commits.

---

## Prerequisites Check

Before running `fvb`, verify if the `fvb` executable is available or execute it via `dart run bin/fvb.dart`:
```bash
fvb --help
```
If `fvb` is not installed globally, agents can run `dart pub global activate --source git https://github.com/chamod-rashmith/flutter-version-bumper` or invoke local execution via `dart run bin/fvb.dart`.

---

## Command Patterns for AI Agents

### 1. Standard SemVer Bumping
- **Patch Release (Bug fixes)**:
  ```bash
  fvb
  ```
- **Minor Release (New backward-compatible features)**:
  ```bash
  fvb -b minor
  ```
- **Major Release (Breaking API changes)**:
  ```bash
  fvb -b major
  ```
- **Build-Number-Only Release**:
  ```bash
  fvb -b build
  ```

### 2. Pre-Release Workflow
- **Start or Bump Beta Track**:
  ```bash
  fvb --pre beta
  ```
- **Transition to Release Candidate (RC)**:
  ```bash
  fvb --pre rc
  ```
- **Promote to Stable Track**:
  ```bash
  fvb -b patch
  ```

### 3. Automated CHANGELOG.md Updating
- **Bump with Changelog Entry**:
  ```bash
  fvb -c --changelog-msg "Added authentication and dark mode features"
  ```

### 4. Complete Release Pipeline (Bump + Changelog + Git Commit + Tag + Push)
- **Execute Full Release**:
  ```bash
  fvb -b minor -c --changelog-msg "Release notes" -g -t --git-push
  ```

### 5. Git Hooks Setup
- **Install Pre-Commit Hook**:
  ```bash
  fvb --install-hook pre-commit
  ```

---

## Agent Safety Rules

1. **Always Preview with Dry Run when uncertain**:
   Use `fvb -d` to preview exact version changes and git actions before modifying files.
2. **JSON Parsing for Tool Calls**:
   Use `fvb --json` to get structured machine-readable JSON output:
   ```json
   {
     "success": true,
     "previous_version": "1.2.0",
     "new_version": "1.3.0",
     "pubspec_path": "/path/to/pubspec.yaml",
     "dry_run": false,
     "git_committed": true,
     "git_tagged": true,
     "git_pushed": true
   }
   ```
3. **Respect Project Configs**:
   If a `.fvb.yaml` file exists in the repository, FVB automatically respects its team default settings.
