# filter-source-helper.nix
This implements primitive a gitignore filter for `builtins.filterSource` via
translation to regexes. I just wanted to see how far I could get with the
current approach and it turns out that I can get quite far.


I highly recommend taking a look at the test files
[test.nix](https://github.com/siers/nix-gitignore/blob/master/test.nix) and
[test.sh](https://github.com/siers/nix-gitignore/blob/master/test.sh)
which show that it mostly correctly mimics the actual gitignore implementation.

Currently, the inverse character classes(`[^a]`), `[\\]` and `[\]]` don't work.

## Usage

Replace the `rev` and `sha256` lines with the output of this command:

```bash
nix-prefetch-git https://github.com/siers/nix-gitignore 2> /dev/null | jq -r '"rev = \"\(.rev)\";\nsha256 = \"\(.sha256)\";"'
```

in this snippet:

```nix
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
```

### Currently failing tests:

```diff
s|code/nix/filter-source-helper master % ./test.sh
/nix/store/z64bfdc8377kbnnh6ihn3pgy9qqdzkv2-test-tree
/nix/store/5sxxq66dqkr1fiw25xiibpizk9wajnpn-test-tree

2a3
> 0-failing/]
5c6,7
< 0-failing/ab
---
> 0-failing/\\
> 0-failing/bb
```
