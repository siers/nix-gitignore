#!/usr/bin/env bash

set -euo pipefail

: "${NIXPKGS_CHANNEL:=nixpkgs-unstable}"

tmpdir=$(mktemp --directory)

echo "nix-gitignore: using test dir $tmpdir"

trap 'rm -rf $tmpdir' EXIT

nix_options=(
  --no-out-link
  --option sandbox true
  --show-trace
  -I "nixpkgs=channel:$NIXPKGS_CHANNEL"
)

cp --no-preserve=all -r "$(nix-build ${nix_options[@]} -E '(import ./test.nix {}).sourceBeforeNormal')" $tmpdir/test-tree-normal
cp --no-preserve=all -r "$(nix-build ${nix_options[@]} -E '(import ./test.nix {}).sourceBeforeRecursive')" $tmpdir/test-tree-recursive
cp --no-preserve=all -r "$(nix-build ${nix_options[@]} -E '(import ./test.nix {}).sourceBeforeGitdir')" $tmpdir/test-tree-gitdir

# HACK:
# fix error
# string '/nix/store/XXXX-test-tree' cannot refer to other paths, at ./nix-gitignore/default.nix:...
test=$(nix-build ${nix_options[@]} -E "(import ./test.nix { sourceBeforeNormal' = $tmpdir/test-tree-normal; sourceBeforeRecursive' = $tmpdir/test-tree-recursive; sourceBeforeGitdir' = $tmpdir/test-tree-gitdir; }).success")

[ -e "$test/success" ] && echo -e '\e[1;32msuccess'
