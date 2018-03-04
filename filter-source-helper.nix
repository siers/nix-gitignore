with (import <nixpkgs> {});

# This probably doesn't work quite the way gitignore does,
# but it might be very close.

# p know that if you ignore "directory" in git, it won't care about
# pegations no matter the order, this will care about the order.

# A slash followed by two consecutive asterisks then a slash matches
# zero or more directories. For example, "a/**/b" matches "a/b",
# "a/x/b", "a/x/y/b" and so on.

let
  tail = l: builtins.elemAt l ((builtins.length l) - 1);

  filterPattern = with builtins; patterns: source:
    (name: _type:
      let
        relPath = lib.removePrefix ((toString source) + "/") name;
        matches = pair: (match (head pair) relPath) != null;
        matched = map (pair: [(matches pair) (tail pair)]) patterns;
      in
        tail (head ((filter head matched) ++ [[true true]]))
    );

  # string -> [[regex bool]]
  gitignoreToPatterns = with builtins; gitignore:
    let
      # regex -> bool
      isComment = i: (match "^(#.*|$)" i) != null;

      # ignore -> [ignore bool]
      computeNegation = l:
        let split = match "^(!?)(.*)" l;
        in [(elemAt split 1) (head split == "!")];

      # ignore -> regex
      substWildcards = replaceStrings
        ["\\*" "\\?" "\\+" "\\." "\\(" "\\)" "\\\\" "**/" "**" "*" "?"]
        ["\\*" "\\?" "\\+" "\\." "\\(" "\\)" "\\\\" ".*" ".*" "[^/]*" "[^/]"];

      # regex -> regex
      handleSlashPref = l:
        let split = (match "^(/?)(.*)" l);
        in
          (if (elemAt split 0) == "/"
          then "^"
          else "(^|.*/)")
          + (elemAt split 1);

      # (regex -> regex) -> [regex bool] -> [regex bool]
      mapPat = f: l: [(f (head l)) (tail l)];
    in
      map (l: mapPat (l: handleSlashPref (substWildcards l))
        (computeNegation l))
      (filter (l: !isList l && !isComment l)
      (split "\n" gitignore));

  # an example to get a rough feel of what the filterPattern does
  sourcePat = builtins.filterSource (filterPattern [
    ["^1.*/2$"  false]
    ["^2.*/30$" true]
    ["^2.*/.*"  false]
  ] ./test-tree ) ./test-tree;

  sourceGit = builtins.filterSource (filterPattern
    (gitignoreToPatterns ''
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
    '') ./test-tree) ./test-tree;

in
  [ sourcePat sourceGit ]
