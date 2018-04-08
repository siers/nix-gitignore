{ lib }:

# An interesting bit from the gitignore(5):
# - A slash followed by two consecutive asterisks then a slash matches
# - zero or more directories. For example, "a/**/b" matches "a/b",
# - "a/x/b", "a/x/y/b" and so on.

let
  debug = a: builtins.trace a a;
  tail = l: builtins.elemAt l ((builtins.length l) - 1);
in rec {
  # [["good/relative/source/file" true] ["bad.tmpfile" false]] -> root -> path
  filterPattern = with builtins; patterns: root:
    (name: _type:
      let
        relPath = lib.removePrefix ((toString root) + "/") name;
        matches = pair: (match (head pair) relPath) != null;
        matched = map (pair: [(matches pair) (tail pair)]) patterns;
      in
        tail (tail ([[true true]] ++ (filter head matched)))
    );

  # string -> [[regex bool]]
  gitignoreToPatterns = with builtins; gitignore:
    let
      # ignore -> bool
      isComment = i: (match "^(#.*|$)" i) != null;

      # ignore -> [ignore bool]
      computeNegation = l:
        let split = match "^(!?)(.*)" l;
        in [(elemAt split 1) (head split == "!")];

      # ignore -> regex
      substWildcards =
        let
          special = "^$.+{}()";
          escs = "\\*?";
          chars = s: filter (c: c != "" && !isList c) (split "" s);
          escape = s: map (c: "\\" + c) (chars s);
        in
          replaceStrings
            ((chars special)  ++ (escape escs) ++ ["**/" "**" "*"     "?"])
            ((escape special) ++ (escape escs) ++ [".*"  ".*" "[^/]*" "[^/]"]);

      # (regex -> regex) -> regex -> regex
      mapAroundCharclass = with builtins; f: r: # rl = regex or list
        let slightFix = replaceStrings ["\\]"] ["]"];
        in
          concatStringsSep ""
          (map (rl: if isList rl then slightFix (elemAt rl 0) else f rl)
          (split "(\\[([^\\\\]|\\\\.)+])" r));

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
      map (l: # `l' for "line"
        mapPat (l: handleSlashPref (mapAroundCharclass substWildcards l))
        (computeNegation l))
      (filter (l: !isList l && !isComment l)
      (split "\n" gitignore));

  gitignoreFilter = ign: root: filterPattern (gitignoreToPatterns ign) root;

  gitignoreFilterSourcePure = ign: root:
    builtins.filterSource (gitignoreFilter ign root) root;

  gitignoreFilterSource' = aux: root:
    let gitign = builtins.readFile "${toString root}/.gitignore";
    in gitignoreFilterSourcePure (gitign + "\n" + aux) root;

  gitignoreFilterSource = gitignoreFilterSource' "";
}
