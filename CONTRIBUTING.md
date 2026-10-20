# Contributing to Flutter Version Bumper (FVB) 🤝

First off, thank you for considering contributing to **Flutter Version Bumper (FVB)**! 🎉 Contributions from the community help make this tool faster, safer, and more delightful for Flutter developers worldwide.

Whether you're fixing a bug, adding a new feature, improving documentation, or opening an issue, your help is warmly welcomed.

---

## 📑 Table of Contents
1. [Code of Conduct](#-code-of-conduct)
2. [How Can I Contribute?](#-how-can-i-contribute)
   - [Reporting Bugs](#reporting-bugs)
   - [Suggesting Features](#suggesting-features)
   - [Contributing Code](#contributing-code)
3. [Development Environment Setup](#-development-environment-setup)
4. [Development Workflow](#-development-workflow)
   - [Branch Naming](#branch-naming-convention)
   - [Code Formatting](#code-formatting)
   - [Static Analysis](#static-analysis)
   - [Running Tests](#running-tests)
5. [Commit Message Guidelines](#-commit-message-guidelines)
6. [Pull Request (PR) Checklist](#-pull-request-pr-checklist)
7. [Project Architecture Overview](#-project-architecture-overview)

---

## 📜 Code of Conduct

We are committed to providing a friendly, safe, and welcoming environment for everyone, regardless of experience level, background, or identity. Please be respectful and constructive in all discussions, issues, and pull requests.

---

## 💡 How Can I Contribute?

### Reporting Bugs
Before submitting a bug report, please search [existing issues](https://github.com/chamod-rashmith/flutter-version-bumper/issues) to see if it has already been reported.

When filing a new bug report, please include:
- **A clear, descriptive title**.
- **Steps to reproduce** the issue.
- **Expected vs. Actual behavior**.
- **Environment details**:
  - Operating System (Windows, macOS, Linux)
  - Dart & Flutter versions (`dart --version`, `flutter --version`)
  - FVB version (`fvb --version`)
- **Console output or error trace** (run with `--verbose` or check stderr).

### Suggesting Features
We love ideas! Please check our [ROADMAP.md](ROADMAP.md) first to see if your idea is already planned. If not, open an issue with:
- The problem you want to solve.
- A proposed CLI command syntax or configuration file format.
- Why this would benefit the broader Flutter community.

### Contributing Code
Ready to write some Dart? Check out open issues labeled with [`good first issue`](https://github.com/chamod-rashmith/flutter-version-bumper/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) or [`help wanted`](https://github.com/chamod-rashmith/flutter-version-bumper/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22).

---

## 🛠 Development Environment Setup

### 1. Prerequisites
- **Dart SDK**: `^3.0.0` or higher (included with Flutter SDK or installed via [dart.dev](https://dart.dev/get-dart)).
- **Git**: Installed and configured on your machine.

### 2. Fork and Clone
Fork the repository on GitHub, then clone your fork locally:
```bash
git clone https://github.com/<your-username>/flutter-version-bumper.git
cd flutter-version-bumper
```

### 3. Install Dependencies
Fetch the package dependencies:
```bash
dart pub get
```

### 4. Run the Tool Locally
Run the entry point directly using the Dart VM:
```bash
# Display help menu
dart run bin/fvb.dart --help

# Run in dry-run mode against an example Flutter project
dart run bin/fvb.dart -d -p ./example
```

You can also globally activate your local development version:
```bash
dart pub global activate --source path .
```

---

## 🔄 Development Workflow

### Branch Naming Convention
Create a feature branch from the latest `main` branch:
```bash
git checkout main
git pull origin main
git checkout -b <type>/<short-description>
```

Recommended prefix conventions:
- `feat/` — New features or command-line options (e.g., `feat/rollback-support`)
- `fix/` — Bug fixes (e.g., `fix/windows-crlf-handling`)
- `docs/` — Documentation updates (e.g., `docs/update-readme`)
- `refactor/` — Code refactoring without changing functionality
- `test/` — Adding or updating test suites
- `chore/` — Tooling, dependency, or configuration updates

### Code Formatting
Ensure all files strictly adhere to Dart's official formatting rules:
```bash
dart format .
```
*(CI will fail if code is not formatted).*

### Static Analysis
FVB enforces strict lint rules defined in `analysis_options.yaml` (including `strict-casts`, `strict-inference`, and `strict-raw-types`). Run the analyzer:
```bash
dart analyze --fatal-infos
```
Make sure there are **0 errors, 0 warnings, and 0 linter infos**.

### Running Tests
Every bug fix and feature **must** be accompanied by unit or integration tests in the `test/` folder.
Run the complete test suite:
```bash
dart test
```
To run a specific test file:
```bash
dart test test/fvb_test.dart
```

---

## ✍️ Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. This keeps our Git history organized and enables automated changelog generation.

### Commit Format
```
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

### Types
- `feat`: A new feature (e.g., `feat(cli): add --rollback-on-failure flag`)
- `fix`: A bug fix (e.g., `fix(changelog): handle CRLF line endings on Windows`)
- `docs`: Documentation only changes (e.g., `docs: clarify installation steps in README`)
- `style`: Changes that do not affect code logic (whitespace, formatting)
- `refactor`: Code changes that neither fix a bug nor add a feature
- `perf`: Code changes that improve performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to build process, CI workflows, or auxiliary tools

---

## 📋 Pull Request (PR) Checklist

Before submitting your Pull Request, please verify:
- [ ] My code follows the project's code style and Effective Dart guidelines.
- [ ] I have formatted my code with `dart format .`.
- [ ] `dart analyze --fatal-infos` passes without errors or warnings.
- [ ] `dart test` passes all tests.
- [ ] I have added new tests covering the bug fix or feature.
- [ ] I have updated documentation or README if my change affects user-facing behavior.
- [ ] My commit messages follow [Conventional Commits](#-commit-message-guidelines).

---

## 🏗 Project Architecture Overview

To help you navigate the codebase quickly:

```
bin/
└── fvb.dart                       # CLI executable entrypoint
lib/
├── flutter_version_bumper.dart    # Public library export & bumpVersion API
└── src/
    ├── changelog/                 # ChangelogUpdater for parsing & writing CHANGELOG.md
    ├── cli/                       # ArgParser configuration & InteractiveRunner
    ├── config/                    # FvbConfig YAML parser (.fvb.yaml / pubspec.yaml)
    ├── git/                       # GitAutomation (commit, tag, push) & GitHooks
    ├── models/                    # PubspecVersion (SemVer parsing, bumping, validation)
    ├── skill/                     # AI Agent Skill generator (SKILL.md)
    └── utils/                     # Logger (color, stderr routing) & FileUtils
test/                              # Comprehensive test suites
```

---

## 💬 Getting Help

If you have questions, feel free to open a [Discussion or Issue](https://github.com/chamod-rashmith/flutter-version-bumper/issues) on GitHub. We are happy to help guide you through the contribution process!

Happy coding! 🚀
