#!/usr/bin/env bash
# @describe Export CiviCRM Afform, SavedSearch, and SearchDisplay artifacts into a target extension.
# @meta version 2.2.0
# @meta require-tools bash,php,cv,civix,find,sed,sort
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

# @cmd Choose extension interactively, then export discovered artifacts.
interactive() {
  init_runtime
  preflight
  choose_ext_interactive
  discover "$EXT" "$ITEMS_FILE"

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

EXT=""
TMPBASE=""
LOG_FILE=""
ITEMS_FILE=""

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

preflight() {
  command -v php >/dev/null || die "missing php"
  command -v cv >/dev/null || die "missing cv"
  command -v civix >/dev/null || die "missing civix"

  if [[ "${argc_dry_run:-0}" != 1 ]]; then
    cv api4 System.get --quiet >/dev/null 2>&1 || {
      err "cv cannot reach CiviCRM. Try: cv api4 System.get"
      exit 3
    }
  fi

  is_verbose && err "INFO preflight OK"
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

      $data = @include $file;

      if (!is_array($data)) {
        exit(0);
      }

      foreach ($data as $item) {
        if (!is_array($item)) {
          continue;
        }

        if (($item["entity"] ?? null) !== $want) {
          continue;
        }

        $name = $item["params"]["name"] ?? null;

        if (is_string($name) && $name !== "") {
          echo $name, PHP_EOL;
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
    cv api4 "${entity}.get" \
      select='["id"]' \
      where='[["name","=","'"$name"'"]]' \
      --quiet 2>/dev/null || true
  )"

  if is_debug; then
    safe="$(printf '%s' "$name" | tr '/ ' '__' | tr -cd 'A-Za-z0-9_.-')"
    printf '%s' "$json" > "$TMPBASE/${entity}_${safe}.json" || true
  fi

  [[ -n "$json" ]] || return 0

  php -r '
    $d = json_decode($argv[1], true);
    echo is_array($d) && isset($d[0]["id"]) ? $d[0]["id"] : "";
  ' "$json" 2>/dev/null || true
}

discover_afforms() {
  local ang="$1"
  local out="$2"
  local f
  local name

  [[ -d "$ang" ]] || return 0

  while IFS= read -r f; do
    name="$(basename "$f")"
    name="${name%.aff.php}"
    name="${name%.aff.html}"

    [[ -n "$name" ]] && printf 'afform:%s\n' "$name" >> "$out"
  done < <(
    find "$ang" -maxdepth 1 -type f \( -name '*.aff.php' -o -name '*.aff.html' \) | sort
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

  [[ -s "$file" ]] || return 0

  while IFS= read -r item; do
    [[ -n "$item" ]] && export_one "$item"
  done < "$file"

  say "Done."
}

export_one() {
  local item="$1"
  local val
  local id

  case "$item" in
    afform:*)
      val="${item#afform:}"
      run_cmd "cd $(q "$EXT") && civix export Afform $(q "$val")" \
        || fail_or_warn "Afform export failed: $val"
      ;;

    ss:*)
      val="${item#ss:}"
      is_num "$val" || fail_or_warn "Invalid SavedSearch ID: $val"

      run_cmd "cd $(q "$EXT") && civix export SavedSearch $(q "$val")" \
        || fail_or_warn "SavedSearch export failed: $val"
      ;;

    sd:*)
      val="${item#sd:}"
      is_num "$val" || fail_or_warn "Invalid SearchDisplay ID: $val"

      run_cmd "cd $(q "$EXT") && civix export SearchDisplay $(q "$val")" \
        || fail_or_warn "SearchDisplay export failed: $val"
      ;;

    ss-name:*)
      val="${item#ss-name:}"
      id="$(api4_id_by_name SavedSearch "$val")"

      [[ -n "$id" ]] || fail_or_warn "SavedSearch not found in DB: $val"
      [[ -n "$id" ]] && export_one "ss:$id"
      ;;

    sd-name:*)
      val="${item#sd-name:}"
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
  cv ext:list 2>/dev/null | while IFS= read -r line; do
    ext_key_from_cv_ext_list_line "$line" || true
  done | sort -u
}

choose_ext_interactive() {
  local keys_file="$TMPBASE/ext-keys.txt"
  local paths_file="$TMPBASE/ext-paths.txt"
  local key
  local path
  local idx=0
  local choice

  : > "$keys_file"
  : > "$paths_file"

  list_ext_keys > "$keys_file"

  [[ -s "$keys_file" ]] || die "could not read extension list from: cv ext:list"

  say "Available extensions:"
  say ""

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue

    path="$(cv path -d "$key" 2>/dev/null || true)"

    if [[ -n "$path" && -d "$path" ]]; then
      idx=$((idx + 1))
      printf '%s\t%s\t%s\n' "$idx" "$key" "$path" >> "$paths_file"
      printf '  %3d) %-45s %s\n' "$idx" "$key" "$path"
    fi
  done < "$keys_file"

  [[ -s "$paths_file" ]] || die "no extensions from cv ext:list resolved to filesystem paths via cv path -d"

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
      scan|list|doctor|export_items|export-items|interactive)
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