# export-searchkit

A self-contained Bash CLI to **discover and export CiviCRM SearchKit artifacts** — Afform, SavedSearch, and SearchDisplay — into a target extension.

The final built script is **single-file** and dependency-light.

> Note: The source script may use `argc` during development/build. The released built script is intended to be installed as `/usr/local/bin/export-searchkit`.

## 🚀 Quick install

Install latest version directly:

```sh
curl -fsSL https://raw.githubusercontent.com/sushant-cividesk/export-searchkit/main/install.sh | bash
```

This will:

- Download the latest release
- Install it to `/usr/local/bin/export-searchkit`
- Make it executable

Upgrade later by running the same command again.

## What this tool solves

CiviCRM SearchKit packaging normally requires manual commands like:

```sh
civix export Afform afformNewServiceRequest
civix export SavedSearch 64
civix export SearchDisplay 12
```

Without this tool, the manual workflow can be error-prone because:

- You may need to know SavedSearch/SearchDisplay IDs.
- You may need to run multiple `civix export` commands manually.
- You may need to confirm which extension the artifacts should be exported into.
- You may need to track related Afform, SavedSearch, and SearchDisplay artifacts yourself.
- It is easy to miss related Afform/SearchKit dependencies.

`export-searchkit` helps by providing extension scanning, automatic ID resolution, dry-run previews, and an interactive picker for choosing the target extension and site artifacts without needing to know IDs.

## ✅ What this CLI does

### 1. Auto-discovers artifacts from an extension

The CLI scans your extension and finds:

- Afforms from `ang/*.aff.php` and `ang/*.aff.html`
- SavedSearch records from `managed/*.mgd.php`
- SearchDisplay records from `managed/*.mgd.php`

Example:

```text
Artifacts:
  - afform:afsearchAdvancedEventsLinkedEvents
  - afform:afsearchManageEventTemplates
  - ss-name:AdvancedEvents_Linked_Events
  - ss-name:Event_Templates
```

### 2. Resolves SavedSearch/SearchDisplay IDs automatically

For SavedSearch and SearchDisplay names, it uses `cv api4` to resolve IDs:

```text
ss-name:Event_Templates -> ss:66
sd-name:Linked_Events -> sd:67
```

### 3. Exports with one command

```sh
export-searchkit scan --ext /var/www/html/ext/advanced-events
```

Internally, this runs commands like:

```sh
civix export Afform afsearchManageEventTemplates
civix export SavedSearch 66
```

### 4. Avoids duplicate SearchDisplay exports during scan

When SearchDisplays are already embedded inside SavedSearch managed files, `scan` skips separate SearchDisplay export discovery to avoid duplicate managed definitions.

You can still export SearchDisplays explicitly if needed:

```sh
export-searchkit export-items --ext /path/to/ext sd:67
```

## Interactive mode

Run:

```sh
export-searchkit interactive
```

or:

```sh
export-searchkit -i
```

Interactive mode lets you export without knowing IDs.

Flow:

1. Choose the target extension.
2. Choose what to export:
   - Discovered artifacts from the selected extension
   - Afforms available in the CiviCRM site
   - SavedSearches available in the CiviCRM site
   - SearchDisplays available in the CiviCRM site
   - All site Afforms and SavedSearches
   - All site Afforms, SavedSearches, and SearchDisplays — advanced/manual
3. Choose item number(s), comma-separated, or `all`.
4. Confirm export.
5. The tool runs the relevant `civix export` commands.

Example:

```sh
export-searchkit --dry-run interactive
```

Example picker:

```text
What do you want to export?

  1) Discovered artifacts from this extension
  2) Afforms available in this CiviCRM site
  3) SavedSearches available in this CiviCRM site
  4) SearchDisplays available in this CiviCRM site
  5) All site Afforms and SavedSearches
  6) All site Afforms, SavedSearches, and SearchDisplays advanced/manual
```

### Recommended interactive choices

For normal use, prefer:

```text
1) Discovered artifacts from this extension
2) Afforms available in this CiviCRM site
3) SavedSearches available in this CiviCRM site
5) All site Afforms and SavedSearches
```

Use SearchDisplay-specific options only when you intentionally need standalone SearchDisplay exports:

```text
4) SearchDisplays available in this CiviCRM site
6) All site Afforms, SavedSearches, and SearchDisplays advanced/manual
```

> Use `all` carefully. It can export many site-wide artifacts into the selected extension. Prefer selecting specific item numbers unless you intentionally want a bulk export.

## Commands

```sh
export-searchkit doctor --ext PATH
export-searchkit list --ext PATH
export-searchkit scan --ext PATH
export-searchkit scan --dry-run --ext PATH
export-searchkit export-items --ext PATH ITEM...
export-searchkit interactive
export-searchkit examples
export-searchkit self_test --ext PATH
```

`export-items` and `self-test` aliases are also supported:

```sh
export-searchkit export-items --ext PATH afform:foo
export-searchkit self-test --ext PATH
```

## Item formats

```text
afform:NAME     Export Afform by name
ss:ID           Export SavedSearch by ID
sd:ID           Export SearchDisplay by ID
NAME            Bare non-numeric value is treated as Afform name
ID              Bare numeric value is treated as SavedSearch ID
ss-name:NAME    Resolve SavedSearch name to ID, then export
sd-name:NAME    Resolve SearchDisplay name to ID, then export
```

Examples:

```sh
export-searchkit export-items --ext my-ext afform:afsearchManageEventTemplates
export-searchkit export-items --ext my-ext ss:66
export-searchkit export-items --ext my-ext sd:67

# also works:
export-searchkit export-items --ext my-ext afsearchManageEventTemplates
export-searchkit export-items --ext my-ext 66
```

## Dry run

Preview commands without writing files:

```sh
export-searchkit scan --dry-run --ext /path/to/ext
```

or:

```sh
export-searchkit --dry-run scan --ext /path/to/ext
```

Dry-run is strongly recommended before any real export.

## Debug and trace modes

| Flag | Behavior |
|---|---|
| `-v`, `--verbose` | Show info logs |
| `-vv`, `--debug` | Show debug logs and save API JSON dumps |
| `-vvv`, `--trace` | Enable shell trace |
| `--keep-tmp` | Keep temporary files after the command finishes |

Examples:

```sh
export-searchkit --debug --keep-tmp scan --dry-run --ext /path/to/ext
export-searchkit --trace --keep-tmp scan --dry-run --ext /path/to/ext
```

## Fail-safe behavior

By default, the script stops when an export fails.

To continue after individual export failures:

```sh
export-searchkit scan --no-strict --ext /path/to/ext
```

## Extension path support

The `--ext` option can be:

```sh
--ext /path/to/ext
--ext /path/to/ext/ang
--ext /path/to/ext/managed/file.php
```

The tool walks upward until it finds the extension root.

Interactive mode can resolve extensions using:

- `cv ext:list`
- `cv path -d`
- Filesystem fallback scanning common extension directories, such as `/ext`, `web/sites/default/files/civicrm/ext`, and `sites/default/files/civicrm/ext`

## Runtime requirements

- bash
- php
- cv
- civix
- find
- sed
- sort
- awk

The tool looks for `cv` and `civix` in:

- `$PATH`
- `./vendor/bin`
- the detected CiviCRM project root `vendor/bin`

## Safety checklist

Before real export:

```sh
export-searchkit doctor --ext /path/to/ext
export-searchkit list --ext /path/to/ext
export-searchkit scan --dry-run --ext /path/to/ext
export-searchkit self_test --ext /path/to/ext
```

Then run:

```sh
export-searchkit scan --ext /path/to/ext
```

After export, the tool reports changed files. If the extension is inside a git repository, it shows git status/diff information. If not, it uses file checksum snapshots and reports whether file content changed.

## Built-in self-test

Run:

```sh
export-searchkit self_test --ext /path/to/ext
```

or:

```sh
export-searchkit self-test --ext /path/to/ext
```

The self-test checks:

- `doctor`
- `list`
- `scan --dry-run`
- `--debug`
- `--trace`
- `--no-strict`
- `export_items`
- `export-items` alias
- `examples`
- `help`
- interactive extension listing
- `-i` alias
- interactive discovered artifact picker
- interactive Afform picker
- interactive SavedSearch picker
- interactive safe all Afform + SavedSearch picker

Expected result:

```text
PASS: all export-searchkit self-tests passed
```

## Examples

Show built-in examples:

```sh
export-searchkit examples
```

Common examples:

```sh
export-searchkit doctor --ext /var/www/html/ext/advanced-events
export-searchkit list --ext /var/www/html/ext/advanced-events
export-searchkit scan --dry-run --ext /var/www/html/ext/advanced-events
export-searchkit scan --ext /var/www/html/ext/advanced-events
```

Interactive:

```sh
export-searchkit interactive
export-searchkit --dry-run interactive
```

Explicit export:

```sh
export-searchkit export-items --ext /var/www/html/ext/advanced-events afform:afsearchManageEventTemplates
export-searchkit export-items --ext /var/www/html/ext/advanced-events ss:65 ss:66
export-searchkit export-items --ext /var/www/html/ext/advanced-events sd:67 sd:68
```

## Development

Source:

```text
src/export-searchkit.sh
```

## 🔨 Build:

```sh
chmod +x build.sh src/export-searchkit.sh
./build.sh
```

Test locally:

```sh
bash -n src/export-searchkit.sh
./build.sh
export-searchkit self_test --ext /path/to/ext
```

## 🚀 Deployment

```sh
scp export-searchkit server:/usr/local/bin/
chmod +x /usr/local/bin/export-searchkit
```

If replacing an existing running script, write to a temp file first, then move it into place:

```sh
scp export-searchkit server:/tmp/export-searchkit
ssh server 'sudo install -m 0755 /tmp/export-searchkit /usr/local/bin/export-searchkit'
```

This avoids temporary `Text file busy` errors.

## 🧠 How it works

### Discovery

```text
ang/      -> Afform files
managed/  -> SavedSearch/SearchDisplay managed files
```

### Resolution

```sh
cv api4 SavedSearch.get
cv api4 SearchDisplay.get
```

### Execution

```sh
civix export Afform ...
civix export SavedSearch ...
civix export SearchDisplay ...
```

## 📦 Versioning and Releases

Releases are automated via commit messages:

| Commit message | Result |
|---|---|
| `release:` | major bump |
| `major-release:` | minor bump |
| `minor-release:` | patch bump |

Example:

```sh
git commit -m "minor-release: fix export bug"
```
