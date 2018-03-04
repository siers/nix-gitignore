with (import <nixpkgs> {});
with (import ./filter-source-patterns.nix { inherit lib; });

let
  # an example to get a rough feel of what the filterPattern does
  sourcePat = builtins.filterSource (filterPattern [
    ["^1.*/2$"  false]
    ["^2.*/30$" true]
    ["^2.*/.*"  false]
  ] ./test-tree ) ./test-tree;

  sourceGit = builtins.filterSource (gitignoreFilter ''
      1-simple/1
      /1-simple/2
      ^1-simple/3

      !2-*/1?
      !2-*/30
      !/40
      !50
      2-*/*

      3-*/*foo.html
      3-*/**/bar.html

      4-*/\*.html
      4-*/o??ther.html
      4-*/o\?ther.html
      4-*/other.html$
    '' ./test-tree) ./test-tree;

in
  [ sourcePat sourceGit ]
