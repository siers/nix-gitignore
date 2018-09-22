# nix-gitignore

(for nix 2.0 or higher)

This implements primitive a gitignore filter for `builtins.filterSource` via
translation to regexes. I just wanted to see how far I could get with the
current approach and as it turns out that I can get quite far.

Please add give this a star iff this project proves to be useful to you.

* [Motivation](#motivation)
* [Example](#example)
* [Usage](#usage)
* [Testing](#testing)
* [Notes](#notes)

## Motivation

If you want to deploy your code from the development directory,
it would make sense to clean out the development/tmp/cache files before copying
your project's source to the nix store. The set of development files you'll
want to clean is likely the same one your gitignore patterns match, so
this is why this is useful.

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
        # Use this string as the gitignore file.

    gitignoreSourcePure ["ignore-this\nignore-that\n", ~/.gitignore] ./source
        # It also accepts a list (of strings and paths) that will be concatenated
        # once the paths are turned to strings via readFile.

    gitignoreSourceAux "supplemental-ignores\n" ./source
        # This one reads ./source/.gitignore and concats the auxiliary ignores.

    gitignoreSource ./source
        # The one stop shop for all your ignoring needs.
        # gitignoreSource = gitignoreSourceAux "";

They're all derived from the `Filter` functions with the first filter argument hardcoded as `(_: _: true)`:

    gitignoreSourcePure = gitignoreFilterSourcePure (_: _: true);
    gitignoreSourceAux = gitignoreFilterSourceAux (_: _: true);
    gitignoreSource = gitignoreFilterSource (_: _: true);

The `filter` accepts the same arguments the `filterSource` function would pass to its filters.
Thus `fn: gitignoreFilterSourcePure fn ""` is extensionally equivalent to `filterSource`.

If you want to make your own filter from scratch, you may use

    gitignoreFilter = ign: root: filterPattern (gitignoreToPatterns ign) root;

## Testing

I highly recommend taking a look at the test files
[test.nix](https://github.com/siers/nix-gitignore/blob/master/test.nix) and
[test.sh](https://github.com/siers/nix-gitignore/blob/master/test.sh)
which show how closely the actual git implementation's being mimicked.
If you find any deviances, please file an issue. I wouldn't be surprised that
some inconsistencies would pop up if one tried to fuzz this.
