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
          splitString =
            let recurse = str : [(substring 0 1 str)] ++
                                 (if str == "" then [] else (recurse (substring 1 (stringLength(str)) str) ));
            in str : recurse str;
          chars = s: filter (c: c != "" && !isList c) (splitString s);
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
      handleSlashPrefix = l:
        let split = (match "^(/?)(.*)" l);
        in
          (if (elemAt split 0) == "/"
          then "^"
          else "(^|.*/)"
          ) + (elemAt split 1);

      # regex -> regex
      handleSlashSuffix = l:
        let split = (match "^(.*)/$" l);
        in if split != null then (elemAt split 0) + "($|/.*)" else l;

      # (regex -> regex) -> [regex bool] -> [regex bool]
      mapPat = f: l: [(f (head l)) (tail l)];
    in
      map (l: # `l' for "line"
        mapPat (l: handleSlashSuffix (handleSlashPrefix (mapAroundCharclass substWildcards l)))
        (computeNegation l))
      (filter (l: !isList l && !isComment l)
      (split "\n" gitignore));

  gitignoreFilter = ign: root: filterPattern (gitignoreToPatterns ign) root;

  # filterSource derivatives

  gitignoreFilterSourcePure = filter: ign: root:
    builtins.filterSource
      (name: type:
        gitignoreFilter ign root name type
        &&
        filter name type
      ) root;

  gitignoreFilterSourceAux = filter: aux: root:
    let gitign = builtins.readFile "${toString root}/.gitignore";
    in gitignoreFilterSourcePure filter (gitign + "\n" + aux) root;

  gitignoreFilterSource = filter: gitignoreFilterSourceAux filter "";

  # "Filter"-less alternatives

  gitignoreSourcePure = gitignoreFilterSourcePure (_: _: true);
  gitignoreSourceAux = gitignoreFilterSourceAux (_: _: true);
  gitignoreSource = gitignoreFilterSource (_: _: true);
}
