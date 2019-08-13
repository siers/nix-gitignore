#!/usr/bin/env bash

set -euo pipefail

trap 'rm -rf localtmp' EXIT
rm -rf localtmp
mkdir localtmp

cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceBeforeNormal')" localtmp/test-tree-normal
cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceBeforeRecursive')" localtmp/test-tree-recursive
cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceBeforeGitdir')" localtmp/test-tree-gitdir

# HACK:
# fix error
# string '/nix/store/XXXX-test-tree' cannot refer to other paths, at ./nix-gitignore/default.nix:...
test=$(nix-build --no-out-link -E "(import ./test.nix { sourceBeforeNormal' = ./localtmp/test-tree-normal; sourceBeforeRecursive' = ./localtmp/test-tree-recursive; sourceBeforeGitdir' = ./localtmp/test-tree-gitdir; }).success")

[ -e "$test/success" ] && echo -e '\e[1;32msuccess'
