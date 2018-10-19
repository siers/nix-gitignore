{ lib, runCommand }:

# An interesting bit from the gitignore(5):
# - A slash followed by two consecutive asterisks then a slash matches
# - zero or more directories. For example, "a/**/b" matches "a/b",
# - "a/x/b", "a/x/y/b" and so on.

with builtins;

let
  debug = a: trace a a;
  last = l: elemAt l ((length l) - 1);

  throwIfOldNix = let required = "2.0.0"; in
    if compareVersions nixVersion required == -1
    then throw "nix (v${nixVersion} =< v${required}) is too old for nix-gitignore"
    else true;
in rec {
  # [["good/relative/source/file" true] ["bad.tmpfile" false]] -> root -> path
  filterPattern = patterns: root:
    (name: _type:
      let
        relPath = lib.removePrefix ((toString root) + "/") name;
        matches = pair: (match (head pair) relPath) != null;
        matched = map (pair: [(matches pair) (last pair)]) patterns;
      in
        last (last ([[true true]] ++ (filter head matched)))
    );

  # string -> [[regex bool]]
  gitignoreToPatterns = gitignore:
    assert throwIfOldNix;
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
      mapAroundCharclass = f: r: # rl = regex or list
        let slightFix = replaceStrings ["\\]"] ["]"];
        in
          concatStringsSep ""
          (map (rl: if isList rl then slightFix (elemAt rl 0) else f rl)
          (split "(\\[([^\\\\]|\\\\.)+])" r));

      # regex -> regex
      handleSlashPrefix = l:
        let
          split = (match "^(/?)(.*)" l);
          findSlash = l: if (match ".+/.+" l) != null then "" else l;
          hasSlash = mapAroundCharclass findSlash l != l;
        in
          (if (elemAt split 0) == "/" || hasSlash
          then "^"
          else "(^|.*/)"
          ) + (elemAt split 1);

      # regex -> regex
      handleSlashSuffix = l:
        let split = (match "^(.*)/$" l);
        in if split != null then (elemAt split 0) + "($|/.*)" else l;

      # (regex -> regex) -> [regex, bool] -> [regex, bool]
      mapPat = f: l: [(f (head l)) (last l)];
    in
      map (l: # `l' for "line"
        mapPat (l: handleSlashSuffix (handleSlashPrefix (mapAroundCharclass substWildcards l)))
        (computeNegation l))
      (filter (l: !isList l && !isComment l)
      (split "\n" gitignore));

  gitignoreFilter = ign: root: filterPattern (gitignoreToPatterns ign) root;

  # string|[string|file] (→ [string|file] → [string]) -> string
  gitignoreCompileIgnore = aux: root:
    let
      onPath = f: a: if typeOf a == "path" then f a else a;
      string_aux_list = map (onPath readFile) (lib.toList aux);
    in concatStringsSep "\n" string_aux_list;

  gitignoreFilterPure = filter: ign: root: name: type:
    gitignoreFilter (gitignoreCompileIgnore ign root) root name type
    && filter name type;

  # rootPath → gitignoresConcatenated
  compileRecursiveGitignore = root:
    let
      dirOrIgnore = file: type: baseNameOf file == ".gitignore" || type == "directory";
      ignores = builtins.filterSource dirOrIgnore root;
    in readFile (
      runCommand "${baseNameOf root}-recursive-gitignore" {} ''
        cd ${ignores}

        find -type f -exec sh -c '
          rel="$(realpath --relative-to=. "$(dirname "$1")")/"
          if [ "$rel" = "./" ]; then rel=""; fi

          awk -v prefix="$rel" -v root="$1" -v top="$(test -z "$rel" && echo 1)" "
            BEGIN { print \"# \"root }

            /^[^\/]/ {
              if (top) { middle = \"\" } else { middle = \"**/\" }
              print prefix middle \$0
            }

            /^\// {
              if (!top) sub(/^\//, \"\")
              print prefix\$0
            }

            END { print \"\" }
          " "$1"
        ' sh {} \; > $out
      '');

  withGitignoreFile = aux: root:
    lib.toList aux ++ [(compileRecursiveGitignore root)];

  # filterSource derivatives

  gitignoreFilterSourcePure = filter: ign: root:
    filterSource (gitignoreFilterPure filter ign root) root;

  gitignoreFilterSourceAux = filter: aux: root:
    gitignoreFilterSourcePure filter (withGitignoreFile aux root) root;

  gitignoreFilterSource = filter: gitignoreFilterSourceAux filter "";

  # "Filter"-less alternatives

  gitignoreSourcePure = gitignoreFilterSourcePure (_: _: true);
  gitignoreSourceAux = gitignoreFilterSourceAux (_: _: true);
  gitignoreSource = gitignoreFilterSource (_: _: true);
}
