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

Navigate to the root of your Flutter project (where `pubspec.yaml` is located) and use the `fvb` command.

### **1. Basic Bumping**
By default, running `fvb` without arguments increments the **patch** version.

| Command | Before | After | Action |
| :--- | :--- | :--- | :--- |
| `fvb` | `1.0.0+1` | `1.0.1+2` | Patch increment |
| `fvb -b minor` | `1.0.1+2` | `1.1.0+3` | Minor increment |
| `fvb -b major` | `1.1.0+3` | `2.0.0+4` | Major increment |
| `fvb -b build` | `2.0.0+4` | `2.0.0+5` | Only Build increment |

### **2. Explicit Versioning**
If you need to jump to a specific semantic version while still incrementing the build number:
```bash
fvb --set 2.5.0
```
*Output: `1.0.0+1` → `2.5.0+2`*

### **3. Terminal Output Example**
When you run a bump, FVB provides clear, color-coded feedback:

```text
Current version: 1.0.0+1
New version:     1.1.0+2

[OK] pubspec.yaml updated: 1.0.0+1 -> 1.1.0+2
```

---

## 🛠 Advanced Options

Use the `--help` flag anytime to see the full options:
```bash
fvb --help
```

- `-b, --bump`: Specifies which SemVer part to increment: `major`, `minor`, `patch` (default), or `build`.
- `-s, --set`: Explicitly sets the semantic version string (`X.Y.Z`).
- `-h, --help`: Displays the help menu.

---

## 🤖 CI/CD Integration

FVB is perfect for automated builds. Here’s an example of how to use it in a **GitHub Action** to automatically bump the version on every merge to `main`:

```yaml
jobs:
  bump-version:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1
      
      - name: Install FVB
        run: dart pub global activate --source git https://github.com/chamod-rashmith/flutter-version-bumper
        
      - name: Bump Version
        run: fvb  # Bumps patch + build number
        
      - name: Commit and Push
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add pubspec.yaml
          git commit -m "chore: bump version [skip ci]"
          git push
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
- Git Tagging automations
- Slack/Discord notification support
- Custom versioning formats

Feel free to open an issue or submit a Pull Request.

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.

Created with ❤️ by [Chamod Rashmith](https://github.com/chamod-rashmith)
