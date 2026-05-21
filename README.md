# 🚀 Flutter Version Bumper (FVB)

[![Dart CLI](https://img.shields.io/badge/Dart-CLI-0175C2.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-All-02569B.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Flutter Version Bumper (FVB)** is a professional-grade command-line tool designed to automate the process of version management in Flutter and Dart projects. It eliminates the manual burden of editing `pubspec.yaml`, ensuring that your versioning follows **Semantic Versioning (SemVer)** principles while keeping build numbers consistent across every release.

---

## 🛠 Why FVB?

In a standard Flutter development workflow, updating versions manually is error-prone. Developers often forget to increment the build number or accidentally break the YAML structure. **FVB** solves this by:

- **Automating Build Numbers**: Every time you bump a version part (`major`, `minor`, or `patch`), the build number (the number after the `+`) is automatically incremented.
- **Ensuring Consistency**: It handles the logic of resetting lower-priority version segments (e.g., bumping `minor` resets `patch` to `0`).
- **Cross-Platform Compatibility**: Being built with Dart, it runs natively on macOS, Windows, and Linux without needing complex environment setups.

## 📋 Prerequisites

Before installing, ensure you have the following requirements:
- **Dart SDK**: `^3.0.0` or higher.
- **Flutter** (Optional, but recommended for mobile development).

---

## 🚀 Installation

Install the tool globally using Dart's package manager to make the `fvb` command available everywhere on your machine.

### **Method 1: From GitHub (Recommended)**
```bash
dart pub global activate --source git https://github.com/chamod-rashmith/flutter-version-bumper
```

### **Method 2: Locally (For Development)**
If you've cloned the repository, run this from the root folder:
```bash
dart pub global activate --source path .
```

---

## ⚡ Usage Guide

Navigate to the root of your Flutter project (where `pubspec.yaml` is located) or specify the path explicitly.

### **1. Basic Bumping**
By default, running `fvb` without arguments increments the **patch** version.

| Command | Before | After | Action |
| :--- | :--- | :--- | :--- |
| `fvb` | `1.0.0+1` | `1.0.1+2` | Patch increment |
| `fvb -b minor` | `1.0.1+2` | `1.1.0+3` | Minor increment |
| `fvb -b major` | `1.1.0+3` | `2.0.0+4` | Major increment |
| `fvb -b build` | `2.0.0+4` | `2.0.0+5` | Only Build increment |

### **2. Premium Customizations**

#### 🎮 Interactive Mode
Run FVB in step-by-step interactive mode:
```bash
fvb -i
```

#### 📦 Full SemVer & Pre-releases
FVB supports pre-release suffixes (e.g., `-beta.1`, `-rc.3`) and build metadata:
- **Start or Bump Pre-release**: `fvb --pre beta` starts or increments a `beta` prerelease track (e.g. `1.0.0` -> `1.0.1-beta.1+2` -> `1.0.1-beta.2+3`).
- **Transition Pre-release Labels**: `fvb --pre rc` transitions the prerelease track (e.g. `1.0.1-beta.2+3` -> `1.0.1-rc.1+4`).
- **Stable Promotion**: Promotes to stable track by running the standard bump command without the `--pre` flag (e.g., `1.0.1-rc.1+4` -> `1.0.2+5`).

#### 🔢 Build Number Controls
- **Keep Build Number**: `fvb --keep-build` (or `-k`) keeps the build number unchanged.
- **Explicit Build Number**: `fvb -n 42` overrides the build number to `42`.
- **Remove Build Number**: `fvb --no-build` strips the build number entirely (e.g., `1.0.0`).

#### 🐙 Git Automation
- **Commit changes**: `fvb -g` (automatically stages and commits the `pubspec.yaml` update).
- **Commit and tag**: `fvb -g -t` (creates a Git tag for the new version).
- **Commit, tag, and push**: `fvb --git-push` (stages, commits, and pushes changes to the remote origin tracking branch).
  > [!NOTE]
  > Specifying `--git-push` automatically enables `--git` (commit) under the hood. To push tags as well, combine it with the tagging flag: `fvb -t --git-push`.
- **Customize commit message**: `fvb -g -m "chore(release): bump version to {version}"`
- **Customize tag prefix**: `fvb -t --tag-prefix "release-"`

#### 🧪 Dry-Run Simulation
- Simulate the bump to preview outputs and git commands without modifying any files: `fvb -d`

#### 📂 Custom Paths & Monorepos
- Bump version for a specific sub-package or directory: `fvb --path packages/my_feature_app`

#### 🤖 Quiet & JSON (CI/CD Pipelines)
- Output raw JSON details: `fvb --json`
- Suppress normal CLI output: `fvb -q`

---

## 🛠 Advanced Options

Use the `--help` flag anytime to see the full options:
```bash
fvb --help
```

- `-b, --bump`: Specifies which SemVer part to increment: `major`, `minor`, `patch` (default), or `build`.
- `-s, --set`: Explicitly sets the full version string (e.g., `2.0.0-beta.1+3`).
- `-n, --build-number`: Explicitly sets the build number segment.
- `-k, --keep-build`: Keeps the current build number instead of auto-incrementing.
- `--no-build`: Completely removes the build number segment.
- `-g, --git`: Automatically commits the `pubspec.yaml` change.
- `-t, --git-tag`: Automatically creates a Git tag for the new version.
- `--git-push`: Automatically pushes committed changes and tags to the remote origin tracking branch.
- `-m, --commit-msg`: Commit message template (uses `{version}` as placeholder).
- `--tag-prefix`: Custom Git tag prefix (defaults to `v`).
- `--pre`: Specify pre-release label and transition to/increment prerelease track (e.g. beta, rc).
- `-d, --dry-run`: Simulates version bumps and prints the outcomes.
- `-p, --path`: Path to the custom `pubspec.yaml` directory or file.
- `-i, --interactive`: Launches a step-by-step interactive CLI interface.
- `-q, --quiet`: Mutes console print statements.
- `--json`: Formats output as a structured JSON string.
- `-h, --help`: Displays the help menu.

---

## 🤖 CI/CD Integration

FVB is perfect for automated builds. You can fully automate version bumping, committing, tagging, and pushing within your CI/CD pipelines in a single command. Here is a **GitHub Action** example:

```yaml
jobs:
  bump-version:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          token: ${{ secrets.PAT_TOKEN }} # Needed to push back to repository
          
      - uses: dart-lang/setup-dart@v1
      
      - name: Install FVB
        run: dart pub global activate --source git https://github.com/chamod-rashmith/flutter-version-bumper
        
      - name: Setup Git User
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          
      - name: Bump, Tag, and Push
        run: fvb -t --git-push # Automates the entire release pipeline
```

---

## 🔧 Troubleshooting

| Issue | Solution |
| :--- | :--- |
| `pubspec.yaml not found` | Ensure you're in the **root directory** of your Flutter project. |
| `Could not parse version` | Ensure your `pubspec.yaml` has exactly `version: X.Y.Z+W`. |
| `fvb command not found` | Add `$HOME/.pub-cache/bin` (macOS/Linux) or `%LOCALAPPDATA%\Pub\Cache\bin` (Windows) to your PATH. |

---

## 🏗 Project Structure

This project follows a professional Dart library structure:
- `bin/`: Contains the executable entry point.
- `lib/`: Contains the core logic and regex parsing.
- `LICENSE`: Open-source MIT license.
- `CHANGELOG.md`: History of all major changes.

---

## 🤝 Contributing

Contributions are welcome! If you have ideas for features like:
- Auto-incrementing native platform files (e.g. `build.gradle` or Xcode configurations)
- Slack/Discord release notification support
- Custom versioning formats

Feel free to open an issue or submit a Pull Request.

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.

Created with ❤️ by [Chamod Rashmith](https://github.com/chamod-rashmith)
