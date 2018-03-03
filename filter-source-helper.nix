with (import <nixpkgs> {});

# A slash followed by two consecutive asterisks then a slash matches
# zero or more directories. For example, "a/**/b" matches "a/b",
# "a/x/b", "a/x/y/b" and so on.

let
  tail = l: builtins.elemAt l ((builtins.length l) - 1);

  filterPattern = with builtins; source: patterns:
    filterSource (name: _type:
      let
        relPath = lib.removePrefix ((toString source) + "/") name;
        matches = pair: (match (head pair) relPath) != null;
        matched = map (pair: [(matches pair) (tail pair)]) patterns;
      in
        tail (head ((filter head matched) ++ [[true true]]))
    ) source;

  gitignoreToPatterns = with builtins; gitignore:
    let
      mapPat = f: l: [(f (head l)) (tail l)];
      isComment = i: (match "^(#.*|$)" i) != null;
      computeNegation = l:
        let split = match "^(!?)(.*)" l;
        in [(elemAt split 1) (head split == "!")];
      substWildcards = replaceStrings
        ["\\*" "\\?" "\\+" "\\." "\\(" "\\)" "\\\\" "**/" "**" "*" "?"]
        ["\\*" "\\?" "\\+" "\\." "\\(" "\\)" "\\\\" ".*" ".*" "[^/]*" "[^/]"];
    in
      map (l: mapPat substWildcards (computeNegation l))
      (filter (l: !isList l && !isComment l)
      (split "\n" gitignore));

  sourcePat = filterPattern ./test-tree [
    ["^1.*/2$"  false]
    ["^2.*/30$" true]
    ["^2.*/.*"  false]
  ];

  sourceGit = filterPattern ./test-tree
    (gitignoreToPatterns ''
      1-simple/2

      !2-*/1?
      !2-*/30
      2-*/*

      3-*/*foo.html
      3-*/**/bar.html

      4-*/\*.html
    '');

in
  [ sourcePat sourceGit ]
