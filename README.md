# export-searchkit

A self-contained Bash CLI to **discover and export CiviCRM SearchKit artifacts** (Afform, SavedSearch, SearchDisplay) into a target extension.

The final built script is **single-file, dependency-light**, and **does NOT require `argc` at runtime**.

## 🚀 Quick install (no clone needed)

Install latest version directly:

```sh
curl -fsSL https://raw.githubusercontent.com/sushant-cividesk/export-searchkit/main/install.sh | bash
````

This will:

* download latest release
* install to `/usr/local/bin/export-searchkit`
* make it executable

Upgrade later by running the same command again.

## 🚀 What this tool solves

CiviCRM SearchKit packaging normally requires manual commands like:

```sh
civix export Afform afformNewServiceRequest
civix export SavedSearch 64
civix export SearchDisplay 12
```

Problems:

* You must **know IDs (e.g. 64)**
* You must **run multiple commands manually**
* You must **know which extension to export into**
* You must **track all related artifacts manually**

## ✅ What this CLI does

### 1. Auto-discovery of artifacts

The CLI scans your extension and finds:

* Afforms → from `ang/*.aff.php` / `.aff.html`
* SavedSearch → from `managed/*.mgd.php`
* SearchDisplay → from `managed/*.mgd.php`

Example output:

```text
Artifacts:
  - afform:afformNewServiceRequest
  - afform:afsearchTabGrant
  - ss-name:Test_Search
  - sd-name:Test_Display
```

### 2. Auto ID resolution (no more guessing)

For SavedSearch & SearchDisplay:

* Uses `cv api4`
* Converts:

```text
ss-name:Test_Search → ss:64
sd-name:Test_Display → sd:12
```

### 3. One-command export

```sh
export-searchkit scan --ext my-extension
```

Runs internally:

```sh
civix export Afform afformNewServiceRequest
civix export SavedSearch 64
civix export SearchDisplay 12
```

### 4. Interactive mode (best UX)

```sh
export-searchkit -i
```

Flow:

1. Lists extensions via `cv ext:list`
2. Lets you choose extension
3. Resolves path via `cv path -d`
4. Scans artifacts
5. Asks confirmation
6. Exports everything

### 5. Flexible input support

```sh
export-searchkit export-items --ext my-ext afform:foo
export-searchkit export-items --ext my-ext ss:64
export-searchkit export-items --ext my-ext sd:12

# also works:
export-searchkit export-items --ext my-ext foo
export-searchkit export-items --ext my-ext 64
```

### 6. Dry run (safe preview)

```sh
export-searchkit scan --ext my-ext --dry-run
```

### 7. Debug & trace modes

| Flag   | Behavior               |
| ------ | ---------------------- |
| `-v`   | Info logs              |
| `-vv`  | Debug logs + API dumps |
| `-vvv` | Full shell trace       |

### 8. Fail-safe behavior

```sh
--no-strict
```

Continues even if one export fails.

### 9. Extension auto-detection

Works with:

```sh
--ext path/to/ext
--ext path/to/ext/ang
--ext path/to/ext/managed/file.php
```

## 📦 Commands

```sh
export-searchkit scan --ext PATH
export-searchkit list --ext PATH
export-searchkit export-items --ext PATH ...
export-searchkit -i
export-searchkit doctor --ext PATH
```

## ⚙️ Runtime requirements

* bash
* php
* cv
* civix

## 🛠 Development

Source:

```text
src/export-searchkit.sh
```

## 🔨 Build

```sh
chmod +x build.sh src/export-searchkit.sh
./build.sh
```

## 🚀 Deployment

```sh
scp export-searchkit server:/usr/local/bin/
```

## 🧠 How it works

### Discovery

* `ang/` → Afforms
* `managed/` → SavedSearch + SearchDisplay

### Resolution

```sh
cv api4 SavedSearch.get
cv api4 SearchDisplay.get
```

### Execution

```bash
civix export ...
```

## 🔐 Safety features

* `--dry-run`
* `--keep-tmp`
* strict/non-strict modes

## 📦 Versioning & Releases

Releases are automated via commit messages:

| Commit message   | Result                       |
| ---------------- | ---------------------------- |
| `release:`       | major bump (v1 → v2)         |
| `major-release:` | minor bump (v1.0 → v1.1)     |
| `minor-release:` | patch bump (v1.0.0 → v1.0.1) |

Example:

```sh
git commit -m "minor-release: fix export bug"
```
