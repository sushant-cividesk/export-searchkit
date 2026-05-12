#!/usr/bin/env bash
# @describe Export CiviCRM Afform, SavedSearch, and SearchDisplay artifacts into a target extension.
# @meta version 1.0.0
# IMPORTANT:
# Do NOT list cv/civix in require-tools.
# We resolve them ourselves because many CiviCRM projects keep them in ./vendor/bin.
# @meta require-tools bash,php,find,sed,sort,awk
# @meta inherit-flag-options

# @option --ext <PATH> Target extension root, or any path inside the target extension.
# @flag --dry-run Print commands without executing.
# @flag -v --verbose Show basic progress/info logs.
# @flag --debug Show debug logs and save API JSON dumps. Also available as -vv.
# @flag --trace Enable shell tracing. Also available as -vvv.
# @flag --keep-tmp Keep temp files after exit.
# @flag --no-strict Continue after export failures.
# @flag -y --yes Answer yes to prompts.
# @flag -i --interactive Choose extension interactively and export discovered artifacts.

# @cmd Scan extension and export discovered Afform/SearchKit artifacts.
# @arg path <PATH> Path inside extension.
scan() {
  local path="${argc_path:-${argc_ext:-.}}"

  init_runtime
  resolve_ext "$path"
  preflight
  discover "$EXT" "$ITEMS_FILE"

  say "Extension: $EXT"
  print_items "$ITEMS_FILE"
  export_items_file "$ITEMS_FILE"
}

# @cmd List discovered artifacts without exporting.
# @arg path <PATH> Path inside extension.
list() {
  local path="${argc_path:-${argc_ext:-.}}"

  init_runtime
  resolve_ext "$path"
  preflight
  discover "$EXT" "$ITEMS_FILE"

  say "Extension: $EXT"
  print_items "$ITEMS_FILE"
}

# @cmd Check environment and target extension.
# @arg path <PATH> Path inside extension.
doctor() {
  local path="${argc_path:-${argc_ext:-.}}"

  init_runtime
  resolve_ext "$path"
  preflight

  say "export-searchkit OK"
  say "Extension: $EXT"
  say "cv: $CV_BIN"
  say "civix: $CIVIX_BIN"

  if is_verbose; then
    say "Log: $LOG_FILE"
    say "Temp: $TMPBASE"
  fi
}

# @cmd Export explicit items into target extension.
# @arg items* Items: afform:NAME, ss:ID, sd:ID, bare NAME, or bare numeric SavedSearch ID.
export_items() {
  init_runtime
  resolve_ext "${argc_ext:-}"
  preflight

  [[ "${#argc_items[@]}" -gt 0 ]] || die "export-items requires at least one item"

  say "Extension: $EXT"

  for item in "${argc_items[@]}"; do
    export_one "$item"
  done

  say "Done."
}

# @cmd Choose extension interactively, then choose artifacts from extension or site.
interactive() {
  init_runtime
  preflight
  choose_ext_interactive

  choose_interactive_export_items "$ITEMS_FILE"

  say "Extension: $EXT"
  print_items "$ITEMS_FILE"

  [[ -s "$ITEMS_FILE" ]] || exit 0

  if [[ "${argc_yes:-0}" != 1 ]]; then
    read -r -p "Proceed with export? [y/N] " answer
    [[ "$answer" =~ ^[Yy](es)?$ ]] || {
      say "Aborted."
      exit 1
    }
  fi

  export_items_file "$ITEMS_FILE"
}

# @cmd Show common usage examples.
examples() {
  cat <<'EOF'
export-searchkit examples

Basic checks:
  export-searchkit doctor --ext /var/www/html/ext/advanced-events
  export-searchkit list --ext /var/www/html/ext/advanced-events
  export-searchkit scan --dry-run --ext /var/www/html/ext/advanced-events

Export all discovered Afform, SavedSearch, and SearchDisplay artifacts:
  export-searchkit scan --ext /var/www/html/ext/advanced-events

Export and continue if one item fails:
  export-searchkit scan --no-strict --ext /var/www/html/ext/advanced-events

Export one Afform:
  export-searchkit export_items --ext /var/www/html/ext/advanced-events afform:afsearchManageEventTemplates

Export SavedSearch/SearchDisplay by ID:
  export-searchkit export_items --ext /var/www/html/ext/advanced-events ss:65 ss:66 sd:67 sd:68

Dry-run scan:
  export-searchkit --dry-run scan --ext /var/www/html/ext/advanced-events
  export-searchkit scan --dry-run --ext /var/www/html/ext/advanced-events

Dry-run explicit export:
  export-searchkit --dry-run export_items --ext /var/www/html/ext/advanced-events \
    afform:afsearchManageEventTemplates ss:65 sd:67
  export-searchkit export_items --dry-run --ext /var/www/html/ext/advanced-events \
    afform:afsearchManageEventTemplates ss:65 sd:67

Debug export and keep temp logs:
  export-searchkit --debug --keep-tmp scan --ext /var/www/html/ext/advanced-events

Trace shell execution:
  export-searchkit --trace --keep-tmp scan --ext /var/www/html/ext/advanced-events

Interactive extension picker:
  export-searchkit interactive
  export-searchkit -i

Interactive picker with auto-confirm:
  export-searchkit --yes interactive

Interactive picker with site artifact selection:
  export-searchkit interactive
  # Then choose:
  #   1) target extension
  #   2) discovered artifacts, site Afforms, site SavedSearches, or site SearchDisplays
  #   3) item number(s), comma-separated, or all

Run built-in smoke tests:
  export-searchkit self_test --ext /var/www/html/ext/advanced-events

Supported item formats:
  afform:NAME     Example: afform:afsearchManageEventTemplates
  ss:ID           Example: ss:65
  sd:ID           Example: sd:67
  NAME            Bare non-numeric names are treated as Afform names
  ID              Bare numeric values are treated as SavedSearch IDs

Notes:
  --dry-run prints commands without writing files.
  --debug saves API JSON dumps and extra logs.
  --trace enables shell tracing.
  --keep-tmp keeps temp files after the command finishes.
  --no-strict continues after export failures.
EOF
}

interactive_choice_for_path() {
  local path="$1"
  local tmp_root="${TMPDIR:-/tmp}"
  local out="$tmp_root/export-searchkit-choice.$$.out"
  local choice

  printf '999999\n' | "$0" interactive > "$out" 2>&1 || true

  choice="$(
    awk -v target="$path" '
      index($0, target) {
        gsub(/^[[:space:]]+/, "", $0);
        split($0, a, ")");
        print a[1];
        exit;
      }
    ' "$out"
  )"

  rm -f "$out"

  [[ -n "$choice" ]] || die "self-test failed: could not find interactive choice for path: $path"

  printf '%s\n' "$choice"
}

# @cmd Run smoke tests for all main commands and options.
# @arg path <PATH> Path inside extension.
self_test() {
  local path="${argc_path:-${argc_ext:-.}}"
  local tmp_root="${TMPDIR:-/tmp}"
  local out

  mkdir -p "$tmp_root" || die "cannot create temp directory: $tmp_root"
  out="$tmp_root/export-searchkit-self-test.$$.out"

  say "Running export-searchkit self-test..."
  say ""

  say "Test 1: doctor"
  "$0" doctor --ext "$path" > "$out" 2>&1
  grep -q 'export-searchkit OK' "$out" || {
    cat "$out"
    die "self-test failed: doctor did not report OK"
  }
  say "  PASS"

  say "Test 2: list"
  "$0" list --ext "$path" > "$out" 2>&1
  grep -q 'Extension:' "$out" || {
    cat "$out"
    die "self-test failed: list did not print extension"
  }

  if grep -E 'Fatal error|thrown in|undefined function|Class .* not found' "$out" >/dev/null; then
    cat "$out"
    die "self-test failed: list output contains PHP fatal errors"
  fi

  if grep -E 'ss-name:[[:space:]]*$|sd-name:[[:space:]]*$' "$out" >/dev/null; then
    cat "$out"
    die "self-test failed: list output contains empty SavedSearch/SearchDisplay names"
  fi
  say "  PASS"

  say "Test 3: scan --dry-run"
  "$0" scan --dry-run --ext "$path" > "$out" 2>&1
  grep -q 'Done.' "$out" || {
    cat "$out"
    die "self-test failed: dry-run scan did not complete"
  }
  grep -q '+ ' "$out" || {
    cat "$out"
    die "self-test failed: dry-run scan did not print commands"
  }
  say "  PASS"

  say "Test 4: --debug --keep-tmp scan --dry-run"
  "$0" --debug --keep-tmp scan --dry-run --ext "$path" > "$out" 2>&1
  grep -q 'DEBUG' "$out" || {
    cat "$out"
    die "self-test failed: debug output missing"
  }
  grep -q 'Debug files kept:' "$out" || {
    cat "$out"
    die "self-test failed: keep-tmp output missing"
  }
  say "  PASS"

  say "Test 5: --trace --keep-tmp scan --dry-run"
  "$0" --trace --keep-tmp scan --dry-run --ext "$path" > "$out" 2>&1
  grep -q 'set -x\|+ resolve_ext\|+ preflight' "$out" || {
    cat "$out"
    die "self-test failed: trace output missing"
  }
  say "  PASS"

  say "Test 6: scan --no-strict --dry-run"
  "$0" scan --no-strict --dry-run --ext "$path" > "$out" 2>&1
  grep -q 'Done.' "$out" || {
    cat "$out"
    die "self-test failed: no-strict dry-run scan did not complete"
  }
  say "  PASS"

  say "Test 7: export_items --dry-run with discovered first item"
  local first_item
  first_item="$("$0" list --ext "$path" | awk '/  - / {print $2; exit}')"
  [[ -n "$first_item" ]] || die "self-test failed: no discovered items found for export_items test"

  "$0" export_items --dry-run --ext "$path" "$first_item" > "$out" 2>&1
  grep -q 'Done.' "$out" || {
    cat "$out"
    die "self-test failed: export_items dry-run did not complete"
  }
  say "  PASS"

  say "Test 8: export-items alias"
  "$0" export-items --dry-run --ext "$path" "$first_item" > "$out" 2>&1
  grep -q 'Done.' "$out" || {
    cat "$out"
    die "self-test failed: export-items alias did not complete"
  }
  say "  PASS"

  say "Test 9: examples"
  "$0" examples > "$out" 2>&1
  grep -q 'Basic checks:' "$out" || {
    cat "$out"
    die "self-test failed: examples output missing"
  }
  say "  PASS"

  say "Test 10: help"
  "$0" --help > "$out" 2>&1
  grep -q 'COMMANDS:' "$out" || {
    cat "$out"
    die "self-test failed: help output missing commands"
  }
  grep -q 'examples' "$out" || {
    cat "$out"
    die "self-test failed: help output missing examples command"
  }
  grep -q 'self_test' "$out" || {
    cat "$out"
    die "self-test failed: help output missing self_test command"
  }
  say "  PASS"

  say "Test 11: interactive lists filesystem extensions"
  printf '999999\n' | "$0" interactive > "$out" 2>&1 || true
  grep -q 'Available extensions:' "$out" || {
    cat "$out"
    die "self-test failed: interactive did not print available extensions"
  }
  grep -Fq "$path" "$out" || {
    cat "$out"
    die "self-test failed: interactive did not list target extension path"
  }
  say "  PASS"

  say "Test 12: -i alias lists filesystem extensions"
  printf '999999\n' | "$0" -i > "$out" 2>&1 || true
  grep -q 'Available extensions:' "$out" || {
    cat "$out"
    die "self-test failed: -i did not print available extensions"
  }
  grep -Fq "$path" "$out" || {
    cat "$out"
    die "self-test failed: -i did not list target extension path"
  }
  say "  PASS"

  local ext_choice
  ext_choice="$(interactive_choice_for_path "$path")"

  say "Test 13: interactive choose extension then cancel artifact picker"
  printf '%s\nq\n' "$ext_choice" | "$0" interactive > "$out" 2>&1 || true
  grep -q 'What do you want to export?' "$out" || {
    cat "$out"
    die "self-test failed: interactive did not show export source picker"
  }
  say "  PASS"

  say "Test 14: interactive choose discovered artifacts then abort"
  printf '%s\n1\nn\n' "$ext_choice" | "$0" interactive > "$out" 2>&1 || true
  grep -q 'Artifacts:' "$out" || {
    cat "$out"
    die "self-test failed: interactive discovered artifacts did not list artifacts"
  }
  grep -q 'Aborted.' "$out" || {
    cat "$out"
    die "self-test failed: interactive discovered artifacts did not abort safely"
  }
  say "  PASS"

  say "Test 15: interactive choose site Afform then dry-run"
  printf '%s\n2\n1\n' "$ext_choice" | "$0" --dry-run --yes interactive > "$out" 2>&1
  grep -q 'Available Afforms' "$out" || {
    cat "$out"
    die "self-test failed: interactive Afform picker missing"
  }
  grep -q 'afform:' "$out" || grep -q 'civix export Afform' "$out" || {
    cat "$out"
    die "self-test failed: interactive Afform dry-run did not select/export an Afform"
  }
  say "  PASS"

  say "Test 16: interactive choose site SavedSearch then dry-run"
  printf '%s\n3\n1\n' "$ext_choice" | "$0" --dry-run --yes interactive > "$out" 2>&1
  grep -q 'Available SavedSearches' "$out" || {
    cat "$out"
    die "self-test failed: interactive SavedSearch picker missing"
  }
  grep -q 'civix export SavedSearch' "$out" || {
    cat "$out"
    die "self-test failed: interactive SavedSearch dry-run did not export SavedSearch"
  }
  say "  PASS"

  say "Test 17: interactive choose all safe site Afforms and SavedSearches then dry-run"
  printf '%s\n5\nall\n' "$ext_choice" | "$0" --dry-run --yes interactive > "$out" 2>&1
  grep -q 'Available Afforms and SavedSearches' "$out" || {
    cat "$out"
    die "self-test failed: interactive safe all picker missing"
  }
  grep -q 'civix export' "$out" || {
    cat "$out"
    die "self-test failed: interactive safe all dry-run did not print export commands"
  }
  say "  PASS"

  rm -f "$out"

  say ""
  say "PASS: all export-searchkit self-tests passed"
}

EXT=""
TMPBASE=""
LOG_FILE=""
ITEMS_FILE=""
CV_BIN=""
CIVIX_BIN=""

say() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }
die() { err "Error: $*"; exit 2; }

is_verbose() {
  [[ "${argc_verbose:-0}" == 1 || "${argc_debug:-0}" == 1 || "${argc_trace:-0}" == 1 ]]
}

is_debug() {
  [[ "${argc_debug:-0}" == 1 || "${argc_trace:-0}" == 1 ]]
}

is_trace() {
  [[ "${argc_trace:-0}" == 1 ]]
}

init_runtime() {
  TMPBASE="${TMPDIR:-/tmp}/export-searchkit.$$.$(date +%s)"
  mkdir -p "$TMPBASE"

  LOG_FILE="$TMPBASE/run.log"
  ITEMS_FILE="$TMPBASE/items.txt"

  : > "$LOG_FILE"
  : > "$ITEMS_FILE"

  is_trace && set -x

  trap cleanup EXIT
}

cleanup() {
  if [[ "${argc_keep_tmp:-0}" == 1 || "${argc_debug:-0}" == 1 || "${argc_trace:-0}" == 1 ]]; then
    err "Debug files kept: $TMPBASE"
  else
    rm -rf "$TMPBASE" 2>/dev/null || true
  fi
}

q() {
  printf '%q' "$1"
}

is_num() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

abs_path() {
  local input="$1"
  local d
  local f

  [[ -n "$input" ]] || input="."

  if [[ -d "$input" ]]; then
    cd "$input" && pwd
    return 0
  fi

  if [[ -f "$input" ]]; then
    d="$(dirname "$input")"
    f="$(basename "$input")"
    cd "$d" && printf '%s/%s\n' "$(pwd)" "$f"
    return 0
  fi

  d="$(dirname "$input")"
  f="$(basename "$input")"

  if [[ -d "$d" ]]; then
    cd "$d" && printf '%s/%s\n' "$(pwd)" "$f"
    return 0
  fi

  printf '%s\n' "$input"
}

looks_like_ext_root() {
  local p="$1"

  [[ -d "$p" ]] || return 1

  [[ -f "$p/info.xml" ]] && return 0
  [[ -d "$p/ang" ]] && return 0
  [[ -d "$p/managed" ]] && return 0

  return 1
}

find_ext_root() {
  local p="$1"
  local parent

  [[ -f "$p" ]] && p="$(dirname "$p")"

  while :; do
    if looks_like_ext_root "$p"; then
      printf '%s\n' "$p"
      return 0
    fi

    parent="$(dirname "$p")"

    if [[ "$parent" == "$p" ]]; then
      return 1
    fi

    p="$parent"
  done
}

resolve_ext() {
  local hint="$1"
  local abs
  local root

  [[ -n "$hint" ]] || die "provide --ext PATH or a PATH inside the target extension"

  abs="$(abs_path "$hint")"
  root="$(find_ext_root "$abs" || true)"

  [[ -n "$root" ]] || die "could not find extension root by walking up from: $abs"

  EXT="$root"

  if [[ ! -f "$EXT/info.xml" ]]; then
    is_verbose && err "INFO no info.xml found; accepting dev/test extension root because ang/ or managed/ exists: $EXT"
  fi

  is_verbose && err "INFO target extension: $EXT"
}

find_project_root() {
  local start="${1:-$PWD}"
  local p
  local parent

  p="$(abs_path "$start")"

  [[ -f "$p" ]] && p="$(dirname "$p")"

  while :; do
    if [[ -d "$p/vendor/bin" || -f "$p/composer.json" || -f "$p/private/civicrm.settings.php" ]]; then
      printf '%s\n' "$p"
      return 0
    fi

    parent="$(dirname "$p")"

    if [[ "$parent" == "$p" ]]; then
      return 1
    fi

    p="$parent"
  done
}

resolve_tool_from_project() {
  local tool="$1"
  local root=""
  local candidate=""

  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi

  if [[ -x "./vendor/bin/$tool" ]]; then
    printf '%s\n' "./vendor/bin/$tool"
    return 0
  fi

  root="$(find_project_root "$PWD" || true)"
  if [[ -n "$root" && -x "$root/vendor/bin/$tool" ]]; then
    printf '%s\n' "$root/vendor/bin/$tool"
    return 0
  fi

  if [[ -n "$EXT" ]]; then
    candidate="$EXT/../../vendor/bin/$tool"
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi

    candidate="$EXT/../../../vendor/bin/$tool"
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  return 1
}

preflight() {
  command -v php >/dev/null || die "missing php"

  CV_BIN="$(resolve_tool_from_project cv || true)"
  CIVIX_BIN="$(resolve_tool_from_project civix || true)"

  if [[ -z "$CV_BIN" ]]; then
    err "Error: missing tools: cv"
    err ""
    err "Could not find cv in PATH or project vendor/bin."
    err "Run this command from your CiviCRM project root, or add vendor/bin to PATH:"
    err ""
    err "  export PATH=\"\$PWD/vendor/bin:\$PATH\""
    err ""
    exit 3
  fi

  if [[ -z "$CIVIX_BIN" ]]; then
    err "Error: missing tools: civix"
    err ""
    err "Could not find civix in PATH or project vendor/bin."
    err "Run this command from your CiviCRM project root, or add vendor/bin to PATH:"
    err ""
    err "  export PATH=\"\$PWD/vendor/bin:\$PATH\""
    err ""
    exit 3
  fi

  if [[ "${argc_dry_run:-0}" != 1 ]]; then
    "$CV_BIN" ext:list >/dev/null 2>&1 || {
      err "cv cannot reach CiviCRM. Try:"
      err ""
      err "  $CV_BIN ext:list"
      err ""
      exit 3
    }
  fi

  is_verbose && err "INFO preflight OK"
  is_verbose && err "INFO cv: $CV_BIN"
  is_verbose && err "INFO civix: $CIVIX_BIN"
}

run_cmd() {
  say "+ $*"
  printf '%s\n' "+ $*" >> "$LOG_FILE"

  [[ "${argc_dry_run:-0}" == 1 ]] && return 0

  bash -lc "$*" >> "$LOG_FILE" 2>&1
}

fail_or_warn() {
  if [[ "${argc_no_strict:-0}" == 1 ]]; then
    err "Warning: $*"
  else
    err "$*"
    err "Log: $LOG_FILE"
    exit 4
  fi
}

extract_managed_names() {
  local entity="$1"
  local mgd="$2"
  local f

  [[ -d "$mgd" ]] || return 0

  while IFS= read -r f; do
    php -r '
      $file = $argv[1];
      $want = $argv[2];

      $src = file_get_contents($file);
      if ($src === false) {
        exit(0);
      }

      // Strip comments to reduce false positives.
      $src = preg_replace("!/\\*.*?\\*/!s", "", $src);
      $src = preg_replace("!//.*!", "", $src);

      // Find blocks that declare the requested entity.
      $entityPattern = "/[\"\\x27]entity[\"\\x27]\\s*=>\\s*[\"\\x27]" . preg_quote($want, "/") . "[\"\\x27]/";

      if (!preg_match_all($entityPattern, $src, $entityMatches, PREG_OFFSET_CAPTURE)) {
        exit(0);
      }

      foreach ($entityMatches[0] as $match) {
        $pos = $match[1];

        // Look forward from entity declaration for params/name.
        $chunk = substr($src, $pos, 6000);

        if (preg_match("/[\"\\x27]params[\"\\x27]\\s*=>\\s*\\[/", $chunk) &&
            preg_match("/[\"\\x27]name[\"\\x27]\\s*=>\\s*[\"\\x27]([^\"\\x27]+)[\"\\x27]/", $chunk, $m)) {
          echo $m[1], PHP_EOL;
          continue;
        }

        // Some mgd files may put name close to entity without explicit params match.
        if (preg_match("/[\"\\x27]name[\"\\x27]\\s*=>\\s*[\"\\x27]([^\"\\x27]+)[\"\\x27]/", $chunk, $m)) {
          echo $m[1], PHP_EOL;
        }
      }
    ' "$f" "$entity" 2>/dev/null || true
  done < <(
    find "$mgd" -maxdepth 1 -type f -name '*.mgd.php' | sort
  )
}

api4_id_by_name() {
  local entity="$1"
  local name="$2"
  local json
  local safe

  json="$(
    "$CV_BIN" api4 "${entity}.get" \
      select='["id","name"]' \
      where='[["name","=","'"$name"'"]]' \
      limit=1 \
      2>/dev/null || true
  )"

  if is_debug; then
    safe="$(printf '%s' "$name" | tr '/ ' '__' | tr -cd 'A-Za-z0-9_.-')"
    printf '%s' "$json" > "$TMPBASE/${entity}_${safe}.json" || true
  fi

  [[ -n "$json" ]] || return 0

  php -r '
    $raw = $argv[1];
    $d = json_decode($raw, true);

    if (!is_array($d)) {
      exit(0);
    }

    // cv api4 may return either:
    // [ {"id": 123, ...} ]
    // or:
    // { "values": [ {"id": 123, ...} ] }
    if (isset($d[0]["id"])) {
      echo $d[0]["id"];
      exit(0);
    }

    if (isset($d["values"][0]["id"])) {
      echo $d["values"][0]["id"];
      exit(0);
    }
  ' "$json" 2>/dev/null || true
}

discover_afforms() {
  local ang="$1"
  local out="$2"
  local f
  local name

  [[ -d "$ang" ]] || return 0

  while IFS= read -r name; do
    [[ -n "$name" ]] && printf 'afform:%s\n' "$name" >> "$out"
  done < <(
    find "$ang" -maxdepth 1 -type f \( -name '*.aff.php' -o -name '*.aff.html' \) \
      | sed -E 's#.*/##; s/\.aff\.(php|html)$//' \
      | sort -u
  )
}

discover_saved_searches() {
  local mgd="$1"
  local out="$2"
  local name

  [[ -d "$mgd" ]] || return 0

  while IFS= read -r name; do
    [[ -n "$name" ]] && printf 'ss-name:%s\n' "$name" >> "$out"
  done < <(
    extract_managed_names SavedSearch "$mgd" | sort -u
  )
}

discover_search_displays() {
  local mgd="$1"
  local out="$2"
  local name

  [[ -d "$mgd" ]] || return 0

  # If SearchDisplays are already embedded inside SavedSearch managed files,
  # do not separately export them. This prevents duplicate managed definitions.
  if grep -R "'entity'[[:space:]]*=>[[:space:]]*'SearchDisplay'\|\"entity\"[[:space:]]*=>[[:space:]]*\"SearchDisplay\"" "$mgd"/SavedSearch_*.mgd.php >/dev/null 2>&1; then
    is_verbose && err "INFO SearchDisplay entities already embedded in SavedSearch managed files; skipping separate SearchDisplay discovery"
    return 0
  fi

  while IFS= read -r name; do
    [[ -n "$name" ]] && printf 'sd-name:%s\n' "$name" >> "$out"
  done < <(
    extract_managed_names SearchDisplay "$mgd" | sort -u
  )
}

discover() {
  local root="$1"
  local out="$2"
  local ang="$root/ang"
  local mgd="$root/managed"

  : > "$out"

  if is_debug; then
    err "DEBUG root=$root"
    err "DEBUG ang=$ang exists=$([[ -d "$ang" ]] && echo yes || echo no)"
    err "DEBUG mgd=$mgd exists=$([[ -d "$mgd" ]] && echo yes || echo no)"
  fi

  discover_afforms "$ang" "$out"
  discover_saved_searches "$mgd" "$out"
  discover_search_displays "$mgd" "$out"

  if is_debug; then
    err "DEBUG discovered file=$out"
    sed 's/^/DEBUG item=/' "$out" >&2 || true
  fi
}

print_items() {
  local file="$1"

  if [[ ! -s "$file" ]]; then
    say "No artifacts found."
    return 0
  fi

  say "Artifacts:"
  sed 's/^/  - /' "$file"
}

export_items_file() {
  local file="$1"
  local item
  local before="$TMPBASE/files-before.txt"
  local after="$TMPBASE/files-after.txt"

  [[ -s "$file" ]] || return 0

  snapshot_files "$before"

  while IFS= read -r item; do
    [[ -n "$item" ]] && export_one "$item"
  done < "$file"

  say "Done."

  if [[ "${argc_dry_run:-0}" != 1 ]]; then
    show_changed_since_snapshot "$before" "$after"
  fi
}

export_one() {
  local item="$1"
  local val
  local id

  case "$item" in
    afform:*)
      val="${item#afform:}"
      run_cmd "cd $(q "$EXT") && $(q "$CIVIX_BIN") export Afform $(q "$val")" \
        || fail_or_warn "Afform export failed: $val"
      ;;

    ss:*)
      val="${item#ss:}"
      is_num "$val" || fail_or_warn "Invalid SavedSearch ID: $val"

      run_cmd "cd $(q "$EXT") && $(q "$CIVIX_BIN") export SavedSearch $(q "$val")" \
        || fail_or_warn "SavedSearch export failed: $val"
      ;;

    sd:*)
      val="${item#sd:}"
      is_num "$val" || fail_or_warn "Invalid SearchDisplay ID: $val"

      run_cmd "cd $(q "$EXT") && $(q "$CIVIX_BIN") export SearchDisplay $(q "$val")" \
        || fail_or_warn "SearchDisplay export failed: $val"
      ;;

    ss-name:*)
      val="${item#ss-name:}"

      if [[ "${argc_dry_run:-0}" == 1 ]]; then
        say "+ would resolve SavedSearch name: $(q "$val")"
        say "+ would export SavedSearch after DB lookup"
        return 0
      fi

      id="$(api4_id_by_name SavedSearch "$val")"

      [[ -n "$id" ]] || fail_or_warn "SavedSearch not found in DB: $val"
      [[ -n "$id" ]] && export_one "ss:$id"
      ;;

    sd-name:*)
      val="${item#sd-name:}"

      if [[ "${argc_dry_run:-0}" == 1 ]]; then
        say "+ would resolve SearchDisplay name: $(q "$val")"
        say "+ would export SearchDisplay after DB lookup"
        return 0
      fi

      id="$(api4_id_by_name SearchDisplay "$val")"

      [[ -n "$id" ]] || fail_or_warn "SearchDisplay not found in DB: $val"
      [[ -n "$id" ]] && export_one "sd:$id"
      ;;

    *)
      if is_num "$item"; then
        export_one "ss:$item"
      else
        export_one "afform:$item"
      fi
      ;;
  esac
}

ext_key_from_cv_ext_list_line() {
  local line="$1"
  local key=""

  key="$(printf '%s\n' "$line" | awk '{print $1}')"

  [[ -n "$key" ]] || return 1
  [[ "$key" == "Key" ]] && return 1
  [[ "$key" == "---" ]] && return 1
  [[ "$key" == *":"* ]] && return 1

  printf '%s\n' "$key"
}

list_ext_keys() {
  "$CV_BIN" ext:list 2>/dev/null | while IFS= read -r line; do
    ext_key_from_cv_ext_list_line "$line" || true
  done | sort -u
}

find_ext_path_by_key() {
  local key="$1"
  local project_root
  local d
  local info_key

  project_root="$(find_project_root "$PWD" || true)"
  [[ -n "$project_root" ]] || return 1

  for d in \
    "$project_root/ext/$key" \
    "$project_root/ext/${key//_/-}" \
    "$project_root/web/sites/default/files/civicrm/ext/$key" \
    "$project_root/web/sites/default/files/civicrm/ext/${key//_/-}" \
    "$project_root/sites/default/files/civicrm/ext/$key" \
    "$project_root/sites/default/files/civicrm/ext/${key//_/-}"
  do
    [[ -d "$d" ]] && {
      printf '%s\n' "$d"
      return 0
    }
  done

  while IFS= read -r d; do
    [[ -f "$d/info.xml" ]] || continue

    info_key="$(
      php -r '
        $file = $argv[1];
        $xml = @simplexml_load_file($file);
        if ($xml && isset($xml["key"])) {
          echo (string) $xml["key"];
        }
      ' "$d/info.xml" 2>/dev/null || true
    )"

    if [[ "$info_key" == "$key" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done < <(
    find "$project_root" -path '*/vendor' -prune -o -path '*/node_modules' -prune -o -name info.xml -print 2>/dev/null \
      | sed 's#/info.xml$##'
  )

  return 1
}

list_filesystem_extensions() {
  local project_root="$1"
  local base
  local ext_dir
  local key
  local name

  for base in \
    "$project_root/ext" \
    "$project_root/web/sites/default/files/civicrm/ext" \
    "$project_root/sites/default/files/civicrm/ext"
  do
    [[ -d "$base" ]] || continue

    find "$base" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r ext_dir; do
      [[ -f "$ext_dir/info.xml" || -d "$ext_dir/managed" || -d "$ext_dir/ang" ]] || continue

      key="$(
        php -r '
          $dir = $argv[1];
          $info = $dir . "/info.xml";

          if (is_file($info)) {
            $xml = @simplexml_load_file($info);
            if ($xml && isset($xml["key"])) {
              echo (string) $xml["key"];
              exit(0);
            }
          }

          echo basename($dir);
        ' "$ext_dir" 2>/dev/null || basename "$ext_dir"
      )"

      name="$(
        php -r '
          $dir = $argv[1];
          $info = $dir . "/info.xml";

          if (is_file($info)) {
            $xml = @simplexml_load_file($info);
            if ($xml && isset($xml->name)) {
              echo trim((string) $xml->name);
              exit(0);
            }
          }

          echo basename($dir);
        ' "$ext_dir" 2>/dev/null || basename "$ext_dir"
      )"

      printf '%s\t%s\t%s\n' "$key" "$name" "$ext_dir"
    done
  done | sort -u
}

choose_ext_interactive() {
  local keys_file="$TMPBASE/ext-keys.txt"
  local paths_file="$TMPBASE/ext-paths.txt"
  local fs_file="$TMPBASE/ext-filesystem.txt"
  local project_root
  local key
  local name
  local path
  local idx=0
  local choice

  : > "$keys_file"
  : > "$paths_file"
  : > "$fs_file"

  project_root="$(find_project_root "$PWD" || true)"
  [[ -n "$project_root" ]] || die "could not find CiviCRM project root"

  list_ext_keys > "$keys_file" || true
  list_filesystem_extensions "$project_root" > "$fs_file" || true

  say "Available extensions:"
  say ""

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue

    path="$("$CV_BIN" path -d "$key" 2>/dev/null || true)"

    if [[ -z "$path" || ! -d "$path" ]]; then
      path="$(find_ext_path_by_key "$key" || true)"
    fi

    if [[ -n "$path" && -d "$path" ]]; then
      idx=$((idx + 1))
      printf '%s\t%s\t%s\n' "$idx" "$key" "$path" >> "$paths_file"
      printf '  %3d) %-45s %s\n' "$idx" "$key" "$path"
    fi
  done < "$keys_file"

  # Fallback for CiviCRM Standalone/local installs where cv ext:list cannot resolve paths.
  if [[ ! -s "$paths_file" && -s "$fs_file" ]]; then
    while IFS=$'\t' read -r key name path; do
      [[ -n "$key" && -n "$path" && -d "$path" ]] || continue

      idx=$((idx + 1))
      printf '%s\t%s\t%s\n' "$idx" "$key" "$path" >> "$paths_file"
      printf '  %3d) %-45s %s\n' "$idx" "$key" "$path"
    done < "$fs_file"
  fi

  [[ -s "$paths_file" ]] || {
    err "Could not resolve extension paths automatically."
    err ""
    err "Use --ext directly instead:"
    err ""
    err "  export-searchkit scan --ext /var/www/html/ext/advanced-events"
    err "  export-searchkit list --ext /var/www/html/ext/advanced-events"
    err ""
    die "no extensions resolved from cv or filesystem scan"
  }

  say ""
  read -r -p "Choose extension number: " choice

  [[ "$choice" =~ ^[0-9]+$ ]] || die "invalid choice: $choice"

  key="$(awk -F '\t' -v n="$choice" '$1 == n {print $2}' "$paths_file")"
  path="$(awk -F '\t' -v n="$choice" '$1 == n {print $3}' "$paths_file")"

  [[ -n "$key" && -n "$path" ]] || die "invalid choice: $choice"

  EXT="$path"

  say ""
  say "Selected extension: $key"
  say "Path: $EXT"
  say ""
}

api4_list_afforms() {
  "$CV_BIN" api4 Afform.get \
    select='["name","title","server_route"]' \
    orderBy='{"name":"ASC"}' \
    limit=0 2>/dev/null \
    | php -r '
      $raw = stream_get_contents(STDIN);
      $d = json_decode($raw, true);
      if (!is_array($d)) exit(0);

      $rows = isset($d["values"]) ? $d["values"] : $d;

      foreach ($rows as $row) {
        if (empty($row["name"])) continue;

        $name = $row["name"];
        $title = isset($row["title"]) ? $row["title"] : "";
        $route = isset($row["server_route"]) ? $row["server_route"] : "";

        echo "afform:", $name, "\t", $name, "\t", $title, "\t", $route, PHP_EOL;
      }
    '
}

api4_list_saved_searches() {
  "$CV_BIN" api4 SavedSearch.get \
    select='["id","name","label","api_entity"]' \
    orderBy='{"name":"ASC"}' \
    limit=0 2>/dev/null \
    | php -r '
      $raw = stream_get_contents(STDIN);
      $d = json_decode($raw, true);
      if (!is_array($d)) exit(0);

      $rows = isset($d["values"]) ? $d["values"] : $d;

      foreach ($rows as $row) {
        if (empty($row["id"]) || empty($row["name"])) continue;

        $id = $row["id"];
        $name = $row["name"];
        $label = isset($row["label"]) ? $row["label"] : "";
        $entity = isset($row["api_entity"]) ? $row["api_entity"] : "";

        echo "ss:", $id, "\t", $name, "\t", $label, "\t", $entity, PHP_EOL;
      }
    '
}

api4_list_search_displays() {
  "$CV_BIN" api4 SearchDisplay.get \
    select='["id","name","label","type","saved_search_id.name"]' \
    orderBy='{"saved_search_id.name":"ASC","name":"ASC"}' \
    limit=0 2>/dev/null \
    | php -r '
      $raw = stream_get_contents(STDIN);
      $d = json_decode($raw, true);
      if (!is_array($d)) exit(0);

      $rows = isset($d["values"]) ? $d["values"] : $d;

      foreach ($rows as $row) {
        if (empty($row["id"]) || empty($row["name"])) continue;

        $id = $row["id"];
        $name = $row["name"];
        $label = isset($row["label"]) ? $row["label"] : "";
        $type = isset($row["type"]) ? $row["type"] : "";
        $search = isset($row["saved_search_id.name"]) ? $row["saved_search_id.name"] : "";

        echo "sd:", $id, "\t", $name, "\t", $label, "\t", $type . " / " . $search, PHP_EOL;
      }
    '
}

choose_numbered_items() {
  local source_file="$1"
  local out_file="$2"
  local title="$3"
  local numbered_file="$TMPBASE/numbered-items.txt"
  local choice
  local part
  local item
  local max

  : > "$out_file"
  : > "$numbered_file"

  if [[ ! -s "$source_file" ]]; then
    say "No items found for: $title"
    return 0
  fi

  say ""
  say "$title"
  say ""

  awk -F '\t' '
    {
      idx++;
      item=$1;
      name=$2;
      label=$3;
      extra=$4;

      printf "%s\t%s\n", idx, item >> numbered_file;

      display = name;
      if (label != "") {
        display = display " — " label;
      }
      if (extra != "") {
        display = display " [" extra "]";
      }

      printf "  %3d) %s\n", idx, display;
    }
  ' numbered_file="$numbered_file" "$source_file"

  max="$(awk -F '\t' 'END {print $1 + 0}' "$numbered_file")"

  say ""
  say "Choose item number(s), comma-separated. Use 'all' for all, or 'q' to cancel."
  read -r -p "Selection: " choice

  case "$choice" in
    q|Q|quit|QUIT|cancel|CANCEL)
      say "Aborted."
      exit 1
      ;;
    all|ALL)
      awk -F '\t' '{print $2}' "$numbered_file" > "$out_file"
      return 0
      ;;
  esac

  choice="$(printf '%s' "$choice" | tr ',' ' ')"

  for part in $choice; do
    if ! [[ "$part" =~ ^[0-9]+$ ]]; then
      die "invalid selection: $part"
    fi

    if [[ "$part" -lt 1 || "$part" -gt "$max" ]]; then
      die "selection out of range: $part"
    fi

    item="$(awk -F '\t' -v n="$part" '$1 == n {print $2}' "$numbered_file")"
    [[ -n "$item" ]] && printf '%s\n' "$item" >> "$out_file"
  done

  sort -u "$out_file" -o "$out_file"
}

choose_interactive_export_items() {
  local out_file="$1"
  local source_file="$TMPBASE/site-items.txt"
  local choice

  : > "$out_file"
  : > "$source_file"

  say "What do you want to export?"
  say ""
  say "  1) Discovered artifacts from this extension"
  say "  2) Afforms available in this CiviCRM site"
  say "  3) SavedSearches available in this CiviCRM site"
  say "  4) SearchDisplays available in this CiviCRM site"
  say "  5) All site Afforms and SavedSearches"
  say "  6) All site Afforms, SavedSearches, and SearchDisplays advanced/manual"
  say ""
  read -r -p "Choose export source: " choice

  case "$choice" in
    1)
      discover "$EXT" "$out_file"
      ;;
    2)
      api4_list_afforms > "$source_file"
      choose_numbered_items "$source_file" "$out_file" "Available Afforms"
      ;;
    3)
      api4_list_saved_searches > "$source_file"
      choose_numbered_items "$source_file" "$out_file" "Available SavedSearches"
      ;;
    4)
      api4_list_search_displays > "$source_file"
      choose_numbered_items "$source_file" "$out_file" "Available SearchDisplays"
      ;;
    5)
      {
        api4_list_afforms
        api4_list_saved_searches
      } > "$source_file"
      choose_numbered_items "$source_file" "$out_file" "Available Afforms and SavedSearches"
      ;;

    6)
      {
        api4_list_afforms
        api4_list_saved_searches
        api4_list_search_displays
      } > "$source_file"
      choose_numbered_items "$source_file" "$out_file" "Available Afforms, SavedSearches, and SearchDisplays advanced/manual"
      ;;

    q|Q|quit|QUIT|cancel|CANCEL)
      say "Aborted."
      exit 1
      ;;

    *)
      die "invalid export source: $choice"
      ;;
  esac
}

snapshot_files() {
  local out="$1"

  find "$EXT/managed" "$EXT/ang" -type f \
    \( -name '*.mgd.php' -o -name '*.aff.php' -o -name '*.aff.html' \) \
    -exec sha256sum {} \; 2>/dev/null \
    | sed "s#  $EXT/#  #" \
    | sort > "$out"
}

show_changed_since_snapshot() {
  local before="$1"
  local after="$2"

  say ""

  if git -C "$EXT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    say "Git changes after export:"
    git -C "$EXT" status --short || true
    say ""
    say "Changed files:"
    git -C "$EXT" diff --name-only || true
    return 0
  fi

  snapshot_files "$after"

  say "File changes after export:"
  if diff -u "$before" "$after" >/dev/null 2>&1; then
    say "  No file content changes detected."
    say "  This means the exported files were already up to date."
  else
    comm -13 "$before" "$after" | awk "{print \"  changed/new: \" \$2}"
  fi
}

normalize_argv() {
  local out=()
  local arg
  local saw_command=0

  for arg in "$@"; do
    case "$arg" in
      -vv)
        out+=(--debug)
        ;;
      -vvv|-vvvv*)
        out+=(--trace)
        ;;
      -i|--interactive)
        out+=(interactive)
        saw_command=1
        ;;
      export-items)
        out+=(export_items)
        saw_command=1
        ;;
      self-test)
        out+=(self_test)
        saw_command=1
        ;;
      scan|list|doctor|export_items|interactive|examples|self_test)
        out+=("$arg")
        saw_command=1
        ;;
      *)
        out+=("$arg")
        ;;
    esac
  done

  if [[ "${#out[@]}" -eq 0 ]]; then
    out+=(--help)
  elif [[ "$saw_command" -eq 0 ]]; then
    out+=(--help)
  fi

  set -- "${out[@]}"
  eval "$(argc --argc-eval "$0" "$@")"
}

normalize_argv "$@"