#!/usr/bin/env bash

set -eu

create-tree() { (
    mkdir -p "$1"/{1-simple,2-negation,3-wildcards,4-escapes}
    cd "$1"

    mkdir -p 1-simple
    touch 1-simple/{1,2,3,4,5,^,$,^$,$^,[,[[,\\,\\\\}

    mkdir -p 2-negation
    touch 2-negation/{.keep,10,20,30,40,50}

    mkdir -p 3-wildcards/html
    touch 3-wildcards/{foo,bar}.html
    touch 3-wildcards/html/{foo,bar}.html

    mkdir -p 4-escapes
    touch 4-escapes/{{*,o{,_,__,?,}ther}.html,other.html{,\$,\$\$}}
); }

list-sort() {
    find "$1" -printf '%P\n' | sort
}

create-tree test-tree

nix build '(import ./test.nix).git'
git="$(readlink result)"; rm result
nix="$(nix eval '(import ./test.nix).nix' --json | jq -r .)"

echo "$git"
echo "$nix"
echo
diff --color <(list-sort "$git") <(list-sort "$nix") || :

rm -r test-tree
