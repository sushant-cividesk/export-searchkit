# export-searchkit

Self-contained Bash CLI for exporting CiviCRM Afform/SearchKit artifacts into a chosen extension.

The installed script does **not** require `argc` at runtime.

Runtime requirements:

- `bash`
- `php`
- `cv`
- `civix`

## Why this exists

CiviCRM SearchKit packaging often requires commands like:

```sh
civix export Afform afformNewServiceRequest
civix export SavedSearch 64
civix export SearchDisplay 12
```

## Development with argc

This repo keeps the argc source in:

```text
src/export-searchkit.sh
```

## Build/install flow

On dev/build machine:

```sh
chmod +x build.sh src/export-searchkit.sh
./build.sh
```
