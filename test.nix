with (import <nixpkgs> {});
with (import ./. { inherit lib; });

let
  ignores = ''
    1-simple/1
    /1-simple/2
    /1-simple/[35^$[]]
    /1-simple/][\]]
    /1-simple/[^a]b
    /1-simple/[\\]

    2-*/[^.]*
    !2-*/1?
    !2-*/30
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

  source = ./test-tree;

  sourceNix = gitignoreFilterSourceAux
    (name: _: (builtins.match ".*/9-?-expected/.*filter$" name) == null)
    "/9-expected/*ignore\n"
    source;

  sourceGit = runCommand "test-tree-git" {} ''
    mkdir -p $out/tmp; cd $out/tmp
    cp -r ${source}/* .; chmod -R u+w .

    cat ${builtins.toFile "nixgitignore-ignores" ignores} > .gitignore
    ${git}/bin/git init
    ${git}/bin/git status --porcelain --ignored -z | \
      xargs -0rL1 sh -c '${gnugrep}/bin/grep -Po "^!! \K(.*)" <<< "$1" || :' "" | \
      xargs -d'\n' -r rm -r

    # okay, here's the translation
    # "git status -z"         — because without it adds quoting
    # "xargs -0rL1"           — delimit by NUL, don't run if empty, run a command per line
    # "xargs -d'\n'"          — delimit by NL / '\n'

    # "grep -Po '…\K' || :"   — This one's quite a mouthful! Okay…
    #     Perl regexes, print Output, -K look behind without printing it
    #     "|| :" don't trip up set -e, ":" is alias for true

    rm -r .git
    shopt -s dotglob; cp -r ./* ..
    cd $out; rm -rf tmp
  '';


in {
  debug = gitignoreToPatterns ignores;

  ignores = builtins.toFile "nixgitignore-ignores" ignores;

  nix = sourceNix;
  git = sourceGit;
}
