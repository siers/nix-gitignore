with (import <nixpkgs> {});
with (callPackage ./. {});

{ sourceBeforeNormal' ? null, sourceBeforeRecursive' ? null, sourceBeforeGitdir' ? null }:

let
  testLib = ''
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

  createTreeNormal = ''
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

  createTreeRecursive = createTreeNormal + "\n" + ''
    cp -r "$1" "$1" 2>&1 | grep -vq 'cannot copy a directory, .*into itself' || :
  '';

  createTreeGitdir = ''
    touches() { (
        mkdir -p "$1"; cd "$1"; shift
        touch "$@"
    ); }

    create-tree() { (
        mkdir -p "$1"; cd "$1"

        touch testfile
        touch .gitnotignored

        touches .git shouldbeignored
        touches testdir .gitnotignored
    ); }

    create-tree "$1"

    echo "" > "$1/.gitignore"
  '';

  createTreeGitdirtestGit = ''
    touches() { (
        mkdir -p "$1"; cd "$1"; shift
        touch "$@"
    ); }

    create-tree() { (
        mkdir -p "$1"; cd "$1"

        touch testfile
        touch .gitnotignored

        touches testdir .gitnotignored
    ); }

    create-tree "$1"

    echo "" > "$1/.gitignore"
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
    mkdir -p $out;
    bash ${builtins.toFile "create-tree" createTree} $out
   '');

  # sourceBeforeNormal' is a copy of sourceBeforeNormal, which lives in the nix store
  sourceBeforeNormal    = createSourceTree createTreeNormal;
  sourceBeforeRecursive = createSourceTree createTreeRecursive;
  sourceBeforeGitdir    = createSourceTree createTreeGitdir;

  # basic

  sourceActualNormal = gitignoreSource [] sourceBeforeNormal';
  sourceActualRecursive = gitignoreFilterRecursiveSource (_: _: true) [] sourceBeforeRecursive';
  sourceActualGitdir = gitignoreSource [] sourceBeforeGitdir';

  sourceActual_all  = builtins.filterSource (_: _: true) sourceBeforeNormal';
  sourceActual_pure = gitignoreSourcePure [] sourceBeforeNormal';

  # aux

  sourceActualAux = aux: gitignoreFilterSource
    (name: _: (builtins.match ".*/9-?-expected/.*filter$" name) == null)
    aux
    sourceBeforeNormal';

  sourceActual_aux_string        = sourceActualAux "/9-expected/filtered*\n";
  sourceActual_aux_arr_string    = sourceActualAux ["/9-expected/filtered*\n"];
  sourceActual_aux_arr_combined  =
    sourceActualAux ["/9-expected/*ignore\n" (sourceBeforeNormal' + "/aux.gitignore")];

  #

  sourceExpectedFrom = source: runCommand "test-tree-git" {} ''
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

  sourceExpectedNormal    = sourceExpectedFrom sourceBeforeNormal';
  sourceExpectedRecursive = sourceExpectedFrom sourceBeforeRecursive';
  sourceExpectedGitdir    = createSourceTree createTreeGitdirtestGit;

  typeErrorOrDeprecationWarning = gitignoreSource sourceBeforeNormal';

in with builtins; {
  inherit sourceBeforeNormal sourceExpectedNormal sourceActualNormal;
  inherit sourceBeforeRecursive sourceExpectedRecursive sourceActualRecursive;
  inherit sourceBeforeGitdir sourceExpectedGitdir sourceActualGitdir;
  inherit testLib;

  # BEFORE: rm -rf test-tree; cp --no-preserve=all -r "$(nix-build -E '(import ./test.nix {}).sourceBeforeNormal')/test-tree" .
  # nix eval --raw '(((import ./test.nix { sourceBeforeNormal' = ./test-tree; }).debug_compiled))' | jq -r .
  debug_compiled = toJSON (compileRecursiveGitignore sourceBeforeNormal');
  # nix eval '(((import ./test.nix { sourceBeforeNormal' = ./test-tree; }).debug_patterns))' | jq -r . | jq .
  debug_patterns = toJSON (gitignoreToPatterns (compileRecursiveGitignore sourceBeforeNormal'));

  success =
    let
      test = runCommand "nix-gitignore-test" {} ''
        mkdir -p $out; cd $out
        ${testLib}
        test-main ${sourceExpectedNormal} ${sourceActualNormal} && \
        test-main ${sourceExpectedRecursive} ${sourceActualRecursive} && \
        test-main ${sourceExpectedGitdir} ${sourceActualGitdir} && \
        touch $out/success
      '';
    in
      assert sourceActual_all == sourceActual_pure;
      assert sourceActual_aux_string == sourceActual_aux_arr_string;
      assert sourceActual_aux_string == sourceActual_aux_arr_combined;
      assert (tryEval typeErrorOrDeprecationWarning).success == false;
      test;
}
