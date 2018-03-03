with (import <nixpkgs> {});

let
  filterPattern = with builtins; source: patterns:
    filterSource (name: _type:
      let
        tail = l: elemAt l ((length l) - 1);
        relPath = lib.removePrefix ((toString source) + "/") name;
        matches = pair: (match (head pair) relPath) != null;
        matched = map (pair: [(matches pair) (tail pair)]) patterns;
      in
        tail (head ((filter head matched) ++ [[true true]]))
    ) source;

  gitignoreToPatterns = with builtins; gitignore:
    let
      isComment = i: (match "^(#.*|$)" i) != null;
      computeNegation = l:
        let split = match "^(!?)(.*)" l;
        in [(elemAt split 1) (head split == "!")];
    in
      map computeNegation
      (filter (l: !isList l && !isComment l)
      (split "\n" gitignore));

  sourceGit = filterPattern ./test-tree
    (gitignoreToPatterns ''
      b

      # keep d/3
      !d/3
      d/.*
    '');

  sourcePat = filterPattern ./test-tree [
    ["^b$" false]
    ["^d/3$" true]
    ["^d/.*" false]
  ];

in
  [ sourcePat sourceGit ]
