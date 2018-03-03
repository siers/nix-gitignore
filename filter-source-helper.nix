with (import <nixpkgs> {});

let
  patternFilter = with builtins; source: patterns:
    filterSource (name: _type:
      let
        tail = l: elemAt l ((length l) - 1);
        relPath = lib.removePrefix ((toString source) + "/") name;
        matches = pair: (match (head pair) relPath) != null;
        matched = map (pair: [(matches pair) (tail pair)]) patterns;
      in
        tail (head ((filter head matched) ++ [[true true]]))
    ) source;

in
  patternFilter ./test-tree [
    ["^b$" false]
    ["^d/3$" true]
    ["^d/.*" false]
  ]
