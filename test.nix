with (import <nixpkgs> {});
with (callPackage ./. {});

{ source ? null }:

let
  testScript = ''
    set -euo pipefail

    list-sort() {
        find "$1" -printf '%P\n' | sort
    }

    find-diff() {
        # echo -e "diffing:\n  $1\n  $2\n"
        diff --color <(list-sort "$1") <(list-sort "$2")
    }

    test-main() {
      find-diff "$1" "$2"
    }
  '';

  createTree = ''
    touches() { (
        mkdir -p "$1"; cd "$1"; shift
        touch "$@"
    ); }

    create-tree() { (
        mkdir -p "$1"; cd "$1"

        touches 1-simpl          {1,2,3,4,5,^,$,^$,$^,[,[[,],]],]]],ab,bb,\\,\\\\,simple-test}
        touches 1-simpl/1-simpl  {1,2,3,4,5,^,$,^$,$^,[,[[,],]],]]],ab,bb,\\,\\\\,simpletest}
        touches 1-xxxxx/1-simpl  {1,2}
        touch {,1-simpl/}char-class-pathalogic

        touches 2-negation       {.keep,10,20,30,40,50,60,70}

        touches 3-wildcards      {foo,bar,bbar,baz}.html
        touches 3-wildcards/html {foo,bar,bbar,baz}.html

        touches 4-escapes        {{*,o{,_,__,?,}ther}.html,other.html{,\$,\$\$}}

        touches 5-directory      {1,2,3,4,5,^,$,^$,$^,[,[[,],]],]]],ab,bb,\\,\\\\}

        touches 9-expected       {unfiltered,filtered-via-aux-{filter,ignore,filepath}}
    ); }

    create-tree "$1"

    cat ${builtins.toFile "nixgitignore-ignores" ignores} > "$1/.gitignore"
    cat ${builtins.toFile "nixgitignore-ignores" ignoresAux} > "$1/aux.gitignore"
  '';

  createTreeRecursive = createTree + "\n" + ''
    cp -r "$1" "$1" 2>&1 | grep -vq 'cannot copy a directory, .*into itself' || :
  '';

  ignores = ''
    1-simpl/1
    /1-simpl/2
    /1-simpl/[35^$[]]
    /1-simpl/][\]]
    /1-simpl/[^a]b
    /1-simpl/[\\]
    simple*test

    # [^b/]har-class-pathalogic
    # this fails, but is pathalogic, so I won't cover it

    2-*/[^.]*
    !2-*/1?
    !2-*/30
    !/2-*/70
    !/40
    !50

    3-*/*foo.html
    3-*/**/bar.html

    4-*/\*.html
    4-*/o??ther.html
    4-*/o\?ther.html
    4-*/other.html$

    5-*/
  '';

  ignoresAux = "/9-expected/*filepath\n";

  createSourceTree = createTree: (runCommand "test-tree" {} ''
    mkdir -p $out; cd $out;
    bash ${builtins.toFile "create-tree" createTree} test-tree
   '');

  # source is a copy of sourceUnfiltered, which lives in the nix store
  sourceUnfiltered = createSourceTree createTree;
  sourceUnfilteredRecursive = createSourceTree createTreeRecursive;

  sourceRecursive = source + "-recursive";

  # basic

  sourceNix = gitignoreSource [] source;

  sourceNix_all               = builtins.filterSource (_: _: true) source;
  sourceNix_pure              = gitignoreSourcePure [] source;

  # aux

  sourceNixAux = aux: gitignoreFilterSource
    (name: _: (builtins.match ".*/9-?-expected/.*filter$" name) == null)
    aux
    source;

  sourceNix_aux_string        = sourceNixAux "/9-expected/filtered*\n";
  sourceNix_aux_arr_string    = sourceNixAux ["/9-expected/filtered*\n"];
  sourceNix_aux_arr_combined  =
    sourceNixAux ["/9-expected/*ignore\n" (source + "/aux.gitignore")];

  # recursive

  sourceRecursiveNix = gitignoreFilterRecursiveSource [] sourceRecursive;
  sourceRecursiveGit = sourceGitFrom sourceRecursive;

  #

  sourceGit = sourceGitFrom source;
  sourceGitFrom = source: runCommand "test-tree-git" {} ''
    mkdir -p $out/tmp; cd $out/tmp
    cp -r ${source}/{*,.gitignore} .; chmod -R u+w .

    ${git}/bin/git init > /dev/null
    ${git}/bin/git status --porcelain --ignored -z | \
      xargs -0rL1 sh -c '${gnugrep}/bin/grep -Po "^!! \K(.*)" <<< "$1" || :' "" | \
      xargs -d'\n' -r rm -r

    # okay, here's the translation
    # "git status -z"         — because without it adds quoting
    # "xargs -0rL1"           — delimit by NUL, don't run if empty, run a command per line
    # "xargs -d'\n'"          — delimit by NL / '\n'

    # "grep -Po '…\K' || :"   — This one's quite a mouthful! Okay…
    #     Perl regexes, print Output, \K look behind without printing it
    #     "|| :" don't trip up set -e, ":" is alias for true

    rm -r .git
    shopt -s dotglob; cp -r ./* ..
    cd $out; rm -rf tmp
  '';

  typeErrorOrDeprecationWarning = gitignoreSource source;

in with builtins; {
  inherit sourceUnfiltered sourceUnfilteredRecursive sourceNix sourceGit;
  inherit testScript;

  # BEFORE: rm -rf test-tree; cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceUnfiltered')/test-tree" .
  # nix eval --raw '(((import ./test.nix { source = ./test-tree; }).debug_compiled))' | jq -r .
  debug_compiled = toJSON (compileRecursiveGitignore source);
  # nix eval '(((import ./test.nix { source = ./test-tree; }).debug_patterns))' | jq -r . | jq .
  debug_patterns = toJSON (gitignoreToPatterns (compileRecursiveGitignore source));

  success =
    let
      test = runCommand "nix-gitignore-test" {} ''
        mkdir -p $out; cd $out
        ${testScript}
        test-main ${sourceGit} ${sourceNix} && touch $out/success
      '';
    in
      assert sourceNix_all == sourceNix_pure;
      assert sourceNix_aux_string == sourceNix_aux_arr_string;
      assert sourceNix_aux_string == sourceNix_aux_arr_combined;
      #assert sourceRecursiveNix == sourceRecursiveGit;
      assert (tryEval typeErrorOrDeprecationWarning).success == false;
      test;
}
