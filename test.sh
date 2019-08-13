#!/usr/bin/env bash

set -euo pipefail

trap 'rm -rf localtmp' EXIT
rm -rf localtmp
mkdir localtmp

cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfilteredNormal')/test-tree" localtmp/test-tree-normal
cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfilteredRecursive')/test-tree" localtmp/test-tree-recursive
cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfilteredGitdir')/test-tree" localtmp/test-tree-gitdir

# HACK:
# fix error
# string '/nix/store/XXXX-test-tree' cannot refer to other paths, at ./nix-gitignore/default.nix:...
test=$(nix-build --no-out-link -E "(import ./test.nix { sourceUnfilteredNormal' = ./localtmp/test-tree-normal; sourceUnfilteredRecursive' = ./localtmp/test-tree-recursive; sourceUnfilteredGitdir' = ./localtmp/test-tree-gitdir; }).success")

[ -e "$test/success" ] && echo -e '\e[1;32msuccess'
