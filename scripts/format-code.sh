#!/usr/bin/env bash
set -u
set -o pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_FORMAT_CONFIGURATION_URL="https://raw.githubusercontent.com/swiftlang/swift-format/main/.swift-format"
CHECK_ONLY=0

usage() {
  printf 'Usage: %s [--check]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

log() {
  printf '%s\n' "$*"
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

find_files() {
  local root_dir="$1"
  shift
  find "$root_dir" \
    \( -path '*/.git' -o -path '*/.local' -o -path '*/.dart_tool' -o -path '*/build' -o -path '*/.wxt' -o -path '*/node_modules' -o -path '*/.pnpm-store' -o -path '*/.venv' -o -path '*/venv' -o -path '*/.tox' -o -path '*/target' -o -path '*/dist' -o -path '*/coverage' -o -path '*/vendor' -o -path '*/third_party' \) -prune \
    -o "$@"
}

has_file_named() {
  local root_dir="$1"
  local file_name="$2"
  find_files "$root_dir" -type f -name "$file_name" -print -quit | grep -q .
}

has_matching_file() {
  local root_dir="$1"
  shift
  find_files "$root_dir" -type f "$@" -print -quit | grep -q .
}

format_dart() {
  if ! has_file_named "$PROJECT_DIR" pubspec.yaml; then
    return
  fi
  if ! has_command dart; then
    log "Skipped Dart format because dart is unavailable"
    return
  fi

  local args=(format --page-width 80)
  if [ "$CHECK_ONLY" -eq 1 ]; then
    args+=(--output=none --set-exit-if-changed)
  fi

  while IFS= read -r pubspec_file; do
    local package_dir
    package_dir="$(dirname "$pubspec_file")"
    if has_matching_file "$package_dir" \( -name '*.dart' \); then
      log "Dart format: $package_dir"
      (cd "$package_dir" && dart "${args[@]}" .)
    fi
  done < <(find_files "$PROJECT_DIR" -type f -name pubspec.yaml -print)
}

format_node() {
  if ! has_file_named "$PROJECT_DIR" package.json; then
    return
  fi
  if ! has_command pnpm; then
    log "Skipped Node format because pnpm is unavailable"
    return
  fi

  while IFS= read -r package_file; do
    local package_dir
    package_dir="$(dirname "$package_file")"
    if [ ! -d "$package_dir/node_modules" ]; then
      log "Skipped Node format in $package_dir because node_modules is missing"
      continue
    fi

    if [ -f "$package_dir/biome.json" ]; then
      if [ "$CHECK_ONLY" -eq 1 ]; then
        log "Biome check: $package_dir"
        (cd "$package_dir" && pnpm exec biome check --line-width 100 .)
      else
        log "Biome format: $package_dir"
        (cd "$package_dir" && pnpm exec biome format --write --line-width 100 .)
      fi
    else
      log "Skipped Node format in $package_dir because biome.json was not found"
    fi
  done < <(find_files "$PROJECT_DIR" -type f -name package.json -print)
}

format_rust() {
  if ! has_file_named "$PROJECT_DIR" Cargo.toml; then
    return
  fi
  if ! has_command cargo; then
    log "Skipped Rust format because cargo is unavailable"
    return
  fi

  while IFS= read -r cargo_file; do
    local crate_dir
    crate_dir="$(dirname "$cargo_file")"
    if [ "$CHECK_ONLY" -eq 1 ]; then
      log "Rust format check: $crate_dir"
      (cd "$crate_dir" && cargo fmt --all -- --check)
    else
      log "Rust format: $crate_dir"
      (cd "$crate_dir" && cargo fmt --all)
    fi
  done < <(find_files "$PROJECT_DIR" -type f -name Cargo.toml -print)
}

format_go() {
  if ! has_file_named "$PROJECT_DIR" go.mod; then
    return
  fi
  if ! has_command go; then
    log "Skipped Go format because go is unavailable"
    return
  fi

  while IFS= read -r go_mod_file; do
    local module_dir
    module_dir="$(dirname "$go_mod_file")"
    local go_files
    go_files="$(find_files "$module_dir" -type f -name '*.go' -print)"
    if [ -z "$go_files" ]; then
      continue
    fi

    if [ "$CHECK_ONLY" -eq 1 ]; then
      log "Go format check: $module_dir"
      local unformatted
      unformatted="$(printf '%s\n' "$go_files" | xargs gofmt -l)"
      if [ -n "$unformatted" ]; then
        printf '%s\n' "$unformatted"
        return 1
      fi
    else
      log "Go format: $module_dir"
      printf '%s\n' "$go_files" | xargs gofmt -w
    fi
  done < <(find_files "$PROJECT_DIR" -type f -name go.mod -print)
}

format_swift() {
  if ! has_matching_file "$PROJECT_DIR" \( -name '*.swift' \); then
    return
  fi
  if ! has_command swift-format; then
    log "Skipped Swift format because swift-format is unavailable"
    return
  fi

  local swift_files
  swift_files="$(find_files "$PROJECT_DIR" -type f -name '*.swift' -print)"
  if [ -z "$swift_files" ]; then
    return
  fi

  if [ "$CHECK_ONLY" -eq 1 ]; then
    log "Swift format check: $PROJECT_DIR"
    printf '%s\n' "$swift_files" | xargs swift-format lint --configuration "$SWIFT_FORMAT_CONFIGURATION_URL"
  else
    log "Swift format: $PROJECT_DIR"
    printf '%s\n' "$swift_files" | xargs swift-format format --in-place --configuration "$SWIFT_FORMAT_CONFIGURATION_URL"
  fi
}

format_dart
format_node
format_rust
format_go
format_swift
