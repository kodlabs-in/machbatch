#!/bin/zsh

set -euo pipefail

readonly expected_version="${1:?usage: Scripts/verify-release.sh <expected-version>}"
readonly project_root="${0:A:h:h}"
readonly native_architecture="$(uname -m)"

fail() {
  print -u2 -r -- "release verification failed: $1"
  exit 1
}

verify_binary() {
  local binary="$1"
  local architectures linked_libraries

  [[ -x "$binary" ]] || fail "missing executable $binary"

  architectures="$(lipo -archs "$binary")"
  [[ " ${architectures} " == *" ${native_architecture} "* ]] ||
    fail "$(basename "$binary") does not contain ${native_architecture}"

  linked_libraries="$(otool -L "$binary" | tail -n +2)"
  [[ "$linked_libraries" != *"$project_root"* ]] ||
    fail "$(basename "$binary") links to the source checkout"
  [[ "$linked_libraries" != *"/private/tmp/"* ]] ||
    fail "$(basename "$binary") links to a temporary build path"

  print -r -- "verified $(basename "$binary") [${architectures}]"
}

main() {
  local binary_directory expected_identity actual_identity

  swift build --package-path "$project_root" -c release
  binary_directory="$(swift build --package-path "$project_root" -c release --show-bin-path)"

  verify_binary "$binary_directory/machbatch"
  verify_binary "$binary_directory/machbatchd"

  expected_identity="MachBatch ${expected_version} — Slurm 26.05.4 CLI-compatible"
  actual_identity="$("$binary_directory/machbatch" --version)"
  [[ "$actual_identity" == "$expected_identity" ]] ||
    fail "expected '${expected_identity}', got '${actual_identity}'"

  print -r -- "verified identity: ${actual_identity}"
}

main
