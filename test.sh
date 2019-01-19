#!/usr/bin/env bash

set -euo pipefail

trap 'rm -rf test-tree{,-recursive} result' EXIT
rm -rf  test-tree{,-recursive}

cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfiltered')/test-tree" .
cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfilteredRecursive')/test-tree" test-tree-recursive

test=$(nix-build --no-out-link -E '(import ./test.nix { source = ./test-tree; }).success')

[ -e "$test/success" ] && echo -e '\e[1;32msuccess'
