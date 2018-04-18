# nix-gitignore
### (for nix 2.0 or higher)

This implements primitive a gitignore filter for `builtins.filterSource` via
translation to regexes. I just wanted to see how far I could get with the
current approach and it turns out that I can get quite far.

I highly recommend taking a look at the test files
[test.nix](https://github.com/siers/nix-gitignore/blob/master/test.nix) and
[test.sh](https://github.com/siers/nix-gitignore/blob/master/test.sh)
which show how closely the actual git implementation's being mimicked.
If you find any deviances, please file an issue. I wouldn't be surprised that
some inconsistencies would pop up if one tried to fuzz this.

Please add give this a star iff this project proves to be useful to you.

## Example

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
  additionalIgnores = ''
    /this
    /that/**.html
  '';

  source = gitignoreSourceAux additionalIgnores ./source;
in
  "use ${source} here"
```

## Usage

The `default.nix` exports (among other things) six functions. Three of these are:

    gitignoreSourcePure "ignore-this\nignore-that\n" ./source
        # This doesn't read the ./source/.gitignore

    gitignoreSourceAux "supplemental-ignores\n" ./source
        # This one does read ./source/.gitignore and
        # concats the auxiliary ignores.

    gitignoreSource ./source
        # The one stop shop for all your ignoring needs.
        # gitignoreFilterSource = gitignoreFilterSource' "";

They're all derived from the `Filter` functions with the first filter argument hardcoded as `(_: _: true)`:

    gitignoreSourcePure = gitignoreFilterSourcePure (_: _: true);
    gitignoreSourceAux = gitignoreFilterSourceAux (_: _: true);
    gitignoreSource = gitignoreFilterSource (_: _: true);

The `filter` accepts the same arguments the `filterSource` function would pass to its filters.

## Notes

There was a apparent deviance, but that turned out not to be a
bug in the ignoring mechanisms, but the ignored file removal mechanism due to
a combination of `xargs` and `git status` quoting issues,
which have been fixed in [test.nix](https://github.com/siers/nix-gitignore/blob/553d394ba07fefc5a89e2d6a645b895419271060/test.nix#L42-L46).
