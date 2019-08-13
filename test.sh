#!/usr/bin/env bash

set -euo pipefail

trap 'rm -rf  test-tree test-tree-recursive' EXIT
rm -rf  test-tree test-tree-recursive

cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfilteredNormal')/test-tree" test-tree
cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfilteredRecursive')/test-tree" test-tree-recursive

# fix error
# string '/nix/store/XXXX-test-tree' cannot refer to other paths, at ./nix-gitignore/default.nix:...
test=$(nix-build --no-out-link -E "(import ./test.nix { sourceUnfilteredNormal' = ./test-tree; sourceUnfilteredRecursive' = ./test-tree-recursive; }).success")

[ -e "$test/success" ] && echo -e '\e[1;32msuccess'
