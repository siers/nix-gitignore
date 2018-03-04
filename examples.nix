with (import <nixpkgs> {});

let
  nixgitignoreLocal = import ./. { inherit lib; };
  nixgitignoreGithub = import (pkgs.fetchFromGitHub {
    owner = "siers";
    repo = "nix-gitignore";
    rev = "9fe8c3a183be9b10aaa6319b5641b2f23711d5eb";
    sha256 = "0dv0n0igx3yny2jg2bknp9l0qxvv4b032pil743aqwmyivrbbshh";
  }) { inherit lib; };
in
  with nixgitignoreGithub;

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
      /1-simple/[35^$]

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
