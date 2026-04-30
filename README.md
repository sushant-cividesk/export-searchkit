# export-searchkit

A self-contained Bash CLI to **discover and export CiviCRM SearchKit artifacts** (Afform, SavedSearch, SearchDisplay) into a target extension.

The final built script is **single-file, dependency-light**, and **does NOT require `argc` at runtime**.

## 🚀 What this tool solves

CiviCRM SearchKit packaging normally requires manual commands like:

```sh
civix export Afform afformNewServiceRequest
civix export SavedSearch 64
civix export SearchDisplay 12
````

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

* Uses `cv api4` internally
* Converts:

```text
ss-name:Test_Search → ss:64
sd-name:Test_Display → sd:12
```

### 3. One-command export

Instead of multiple commands:

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

1. Lists all extensions using `cv ext:list`
2. Lets you choose extension
3. Resolves path via `cv path -d`
4. Scans artifacts
5. Asks confirmation
6. Exports everything

### 5. Works with flexible input

You can export using:

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

Output:

```sh
+ civix export Afform afformNewServiceRequest
+ civix export SavedSearch 64
+ civix export SearchDisplay 12
```

### 7. Debug & trace modes

| Flag   | Behavior                    |
| ------ | --------------------------- |
| `-v`   | Info logs                   |
| `-vv`  | Debug logs + API dumps      |
| `-vvv` | Full shell trace (`set -x`) |

Debug files stored in temp dir:

```text
/tmp/export-searchkit.*
```

### 8. Fail-safe behavior

* Stops on errors by default
* Optional:

```sh
--no-strict
```

→ continues even if one export fails

### 9. Extension auto-detection

You can pass:

```sh
--ext path/to/ext
--ext path/to/ext/ang
--ext path/to/ext/managed/file.php
```

Script walks up directories to find extension root.

## 📦 Commands

### Scan + export

```sh
export-searchkit scan --ext PATH
```

### List only (no export)

```sh
export-searchkit list --ext PATH
```

### Export specific items

```sh
export-searchkit export-items --ext PATH afform:foo ss:64 sd:12
```

### Interactive mode

```sh
export-searchkit -i
```

### Doctor (environment check)

```sh
export-searchkit doctor --ext PATH
```

## ⚙️ Runtime requirements

* bash
* php
* cv (CiviCRM CLI)
* civix

## 🛠 Development

Source file:

```text
src/export-searchkit.sh
```

Uses:

* `argc` for CLI parsing (dev only)
* compiled into single executable

## 🔨 Build

```sh
chmod +x build.sh src/export-searchkit.sh
./build.sh
```

Output:

```text
./export-searchkit
```

## 🚀 Deployment

Copy built file to any server:

```sh
scp export-searchkit server:/usr/local/bin/
```

No `argc` required on server.

## 🧠 How it works internally

### Discovery

* Reads filesystem:

  * `ang/` → Afforms
  * `managed/` → SavedSearch & SearchDisplay
* Parses `.mgd.php` via PHP runtime

### Resolution

* Calls:

```sh
cv api4 SavedSearch.get
cv api4 SearchDisplay.get
```

### Execution

* Builds commands dynamically
* Executes via:

```bash
bash -lc "civix export ..."
```

## 🔐 Safety features

* `--dry-run` (no execution)
* `--keep-tmp` (debug inspection)
* strict/non-strict modes
* input normalization (IDs vs names)
