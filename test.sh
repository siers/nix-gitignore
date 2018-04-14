#!/usr/bin/env bash

set -euo pipefail

create-tree() { (
    mkdir -p "$1"; cd "$1"

    mkdir -p 0-failing
    touch 0-failing/{\\,\\\\}

    mkdir -p 1-simple
    touch 1-simple/{1,2,3,4,5,^,$,^$,$^,[,[[,],]],]]],ab,bb}

    mkdir -p 2-negation
    touch 2-negation/{.keep,10,20,30,40,50}

    mkdir -p 3-wildcards/html
    touch 3-wildcards/{foo,bar}.html
    touch 3-wildcards/html/{foo,bar}.html

    mkdir -p 4-escapes
    touch 4-escapes/{{*,o{,_,__,?,}ther}.html,other.html{,\$,\$\$}}

    mkdir -p 9-expected
    touch 9-expected/{unfiltered,filtered-via-aux-{filter,ignore}}
); }

list-sort() {
    find "$1" -printf '%P\n' | sort
}

create-tree test-tree
install -m644 "$(nix eval --raw -f test.nix ignores)" ./test-tree/.gitignore

nix build -f test.nix git
git="$(readlink result)"; rm result
nixi="$(nix eval -f test.nix nixIgnore  --json | jq -r .)"
nixfa="$(nix eval -f test.nix nixFilterAux --json | jq -r .)"

# 2/3 of 9-expected/* paths should be printed

echo "diffing:"
echo "  $nixfa"
echo "  $nixi"
echo

diff --color <(list-sort "$nixfa") <(list-sort "$nixi") || :
echo

# a single 0-failing should be printed

echo "diffing:"
echo "  $git"
echo "  $nixi"
echo

diff --color <(list-sort "$git") <(list-sort "$nixi") || :
echo

find $(find "$git" "$nixi" -name '0-*')

rm -r test-tree
