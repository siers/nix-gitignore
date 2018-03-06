# nix-gitignore
This implements primitive a gitignore filter for `builtins.filterSource` via
translation to regexes. I just wanted to see how far I could get with the
current approach and it turns out that I can get quite far.

Please add give this a star iff this project proves to be useful to you.

I highly recommend taking a look at the test files
[test.nix](https://github.com/siers/nix-gitignore/blob/master/test.nix) and
[test.sh](https://github.com/siers/nix-gitignore/blob/master/test.sh)
which show how closely the actual git implementation's being mimicked and the section detailing
the [known differences](#known-deviances-from-gits-implementation).

## Usage

Replace the `rev` and `sha256` lines with the output of this command:

```bash
nix-prefetch-git https://github.com/siers/nix-gitignore 2> /dev/null | jq -r '"rev = \"\(.rev)\";\nsha256 = \"\(.sha256)\";"'
```

in this snippet:

```nix
with (import <nixpkgs> {});

let
  gitignore = import (pkgs.fetchFromGitHub {
    owner = "siers";
    repo = "nix-gitignore";
    rev = "…";
    sha256 = "…";
  }) { inherit lib; };
in
  with gitignore;

let
  ignores = (builtins.readFile ./source/.gitignore) +  ''
    /this
    /that/**.html
  '';

  source = builtins.filterSource (gitignoreFilter ignores ./source) ./source;
in
  "use ${source} here"
```

### Known deviances from git's implementation

For some odd reason `git` matches `\\` on the `[\\]` pattern whereas this `nix-gitignore` matches just the `\`.

```diff
% ./test.sh
/nix/store/1snailhbagighdk7s1ixg4s323bk7gaf-test-tree-git
/nix/store/r1y0djs054z8561xwm0hxrzvvay1yz9s-test-tree

/nix/store/1snailhbagighdk7s1ixg4s323bk7gaf-test-tree-git/0-failing
/nix/store/1snailhbagighdk7s1ixg4s323bk7gaf-test-tree-git/0-failing/\
/nix/store/r1y0djs054z8561xwm0hxrzvvay1yz9s-test-tree/0-failing
/nix/store/r1y0djs054z8561xwm0hxrzvvay1yz9s-test-tree/0-failing/\\

3c3
< 0-failing/\
---
> 0-failing/\\
```

If you find any other deviances, please file an issue.
