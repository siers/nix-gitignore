#!/usr/bin/env bash

set -euo pipefail

trap 'rm -r test-tree result' EXIT
rm -rf test-tree
cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfiltered')/test-tree" .

test=$(nix-build --no-out-link -E '(import ./test.nix { source = ./test-tree; }).success')

[ -e "$test/success" ] && echo -e '\e[1;32msuccess'
