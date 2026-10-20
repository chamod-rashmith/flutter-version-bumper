# 🗺️ Flutter Version Bumper (FVB) Roadmap

Welcome to the **Flutter Version Bumper (FVB)** project roadmap! This document outlines our vision, upcoming milestones, planned features, and estimated target releases.

FVB follows [Semantic Versioning (SemVer)](https://semver.org/) and modern Dart standards to deliver a developer-first release automation tool for Flutter and Dart applications.

---

## 📌 Release Timeline & Milestone Overview

| Milestone | Target Version | Focus Area | Status |
| :--- | :--- | :--- | :--- |
| **Current Stable** | `v1.6.0` | POSIX Exit Codes, Dart 3 Patterns, Windows CRLF, Agent Skills | ✅ **Shipped** |
| **Milestone 1** | `v1.7.0` | Transaction Safety, Rollback Support & Conventional Changelog | 🚧 **Next Up** |
| **Milestone 2** | `v1.8.0` | CI/CD Audit Gate (`fvb verify`), Branch Policies & GPG Signing | 📋 **Planned** |
| **Milestone 3** | `v1.9.0` | Terminal UI (TUI) Enhancements & GitHub/GitLab Releases | 💡 **Proposed** |
| **Major Milestone**| `v2.0.0` | Monorepo / Melos Workspace Support & Extensible Plugins | 🔮 **Future Horizon** |

---

## 🚀 Upcoming Releases & Planned Features

### 🛡️ v1.7.0 — Safety, Rollback & Conventional Changelog *(Target: Next Minor)*
> **Theme**: Reliability, failure resilience, and effortless changelog generation.

#### 1. 🔄 Transactional Release & Rollback Support (`--rollback-on-failure`)
* **Problem**: If network drops during `git push`, or Git hooks reject a commit, or file writes fail midway, the repository is left in an inconsistent state (e.g., `pubspec.yaml` updated but Git commit failed).
* **Feature**:
  - Implement an atomic transaction manager.
  - Automatically backup the pre-bump `pubspec.yaml`, `CHANGELOG.md`, and Git HEAD state in a temporary staging memory or cache.
  - If any step fails (file write, changelog update, git commit, git tag, git push), automatically restore the previous state and clean up created tags or commits.
  - Add `--rollback-on-failure` (enabled by default) and `--no-rollback` override.
  - Add `fvb rollback` command to manually undo the most recent local bump if not yet pushed.

#### 2. 📜 Automated Conventional Commits Changelog (`--auto-changelog`)
* **Problem**: Developers currently need to pass `--changelog-msg "..."` manually.
* **Feature**:
  - Automatically parse Git commit history between the last release tag and `HEAD`.
  - Group commit messages according to [Conventional Commits](https://www.conventionalcommits.org/):
    - 🚀 **Features**: `feat(...)`
    - 🐛 **Bug Fixes**: `fix(...)`
    - ⚡ **Performance**: `perf(...)`
    - 📝 **Documentation**: `docs(...)`
    - 🔧 **Maintenance**: `chore(...)`, `refactor(...)`
  - Append grouped, cleanly formatted bullet points straight into `CHANGELOG.md`.

#### 3. 🪝 Lifecycle Hooks (`pre-bump` & `post-bump` scripts)
* **Feature**: Allow `.fvb.yaml` to define custom automation scripts:
  ```yaml
  fvb:
    hooks:
      pre_bump: "dart test"
      post_bump: "flutter build appbundle --release"
  ```
  If `pre_bump` script fails (exit code != 0), FVB safely cancels the version bump before touching any files.

---

### 🛡️ v1.8.0 — CI/CD Auditing, Security & Branch Governance
> **Theme**: Enterprise-grade CI/CD pipelines, security, and strict version governance.

#### 1. 🔍 CI Audit & Verification Command (`fvb verify` / `fvb check`)
* **Feature**: Standalone command for CI/CD Pull Request (PR) validation workflows:
  - Validates if the version in `pubspec.yaml` was incremented compared to the target branch (e.g. `origin/main`).
  - Checks whether `CHANGELOG.md` has an entry corresponding to the proposed version.
  - Verifies that the new version strictly adheres to SemVer rules (no accidental downgrade or skipped versions).
  - Returns exit code `0` on compliance or standard POSIX exit code `65` (`EX_DATAERR`) on failure for automated PR blocking.

#### 2. 🌿 Branch Release Policies (`allowed_branches`)
* **Feature**: Restrict automated version bumps to designated branches:
  ```yaml
  fvb:
    allowed_branches:
      - main
      - master
      - "release/*"
  ```
  Prevents accidental production releases directly from feature or hotfix branches.

#### 3. 🔐 Cryptographic Git Signing (`--sign-commit`, `--sign-tag`)
* **Feature**: Support GPG / SSH signature creation for commits and tags (`git commit -S` and `git tag -s`), satisfying SOC2 and enterprise supply-chain requirements.

---

### 🎨 v1.9.0 — Rich Interactive Experience & Cloud Releases
> **Theme**: Developer ergonomics, visual diffing, and hosting platform integration.

#### 1. 🖥️ Interactive Terminal UI (TUI) Overhaul
* **Feature**:
  - Full arrow-key terminal navigation in `fvb -i`.
  - Interactive side-by-side or unified diff preview of `pubspec.yaml` and `CHANGELOG.md` before prompting the user for final confirmation.
  - One-click confirmation to execute or safely abort.

#### 2. 🐙 GitHub & GitLab Release Automation (`--create-release`)
* **Feature**:
  - CLI integration with GitHub CLI (`gh`) and GitLab CLI (`glab`) or REST APIs.
  - Automatically creates a GitHub/GitLab release corresponding to the generated Git tag with the generated release notes attached as the release body.

#### 3. 📱 Platform Native File Synchronization
* **Feature**:
  - Optional synchronization of version codes and build numbers into native platform files where Flutter build tools are bypassed:
    - Android: `android/app/build.gradle` or `build.gradle.kts` (`versionCode`, `versionName`)
    - iOS/macOS: `ios/Runner/Info.plist` (`CFBundleShortVersionString`, `CFBundleVersion`)
    - Web: `web/index.html` cache-busting query strings.

---

### 🏢 v2.0.0 — Monorepo Ecosystem & Multi-Package Architecture
> **Theme**: Large-scale architectures, monorepo workspaces, and custom extensibility.

#### 1. 📦 Monorepo & Melos / Dart Workspace Support
* **Feature**:
  - Full support for multi-package repositories and Dart 3.5+ workspaces.
  - Selective or batch bumping:
    ```bash
    fvb --all-packages
    fvb --scope "packages/*"
    ```
  - Automatically updates internal workspace dependency constraints (e.g. updating `package_b`'s dependency on `package_a` when `package_a` bumps).

#### 2. 🔌 Extensible Plugin & Hook System
* **Feature**:
  - Allow developers to write custom Dart plugins or load custom changelog formatters (e.g. KeepAChangelog, GitHub style, internal Jira ticket formatters).

#### 3. 📢 Webhook & Notification Broadcasts
* **Feature**:
  - Broadcast release notifications to Slack, Discord, or Microsoft Teams webhook URLs upon successful release.

---

## 💡 Have an Idea or Feature Request?

We want to hear from you! If you have suggestions or want to see a feature prioritized:
- Open a [Feature Request Issue](https://github.com/chamod-rashmith/flutter-version-bumper/issues)
- Check our [Contributing Guide](CONTRIBUTING.md) to build and submit a Pull Request!
