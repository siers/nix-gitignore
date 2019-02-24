# nix-gitignore

(for nix 2.0 or higher)

This implements primitive a gitignore filter for `builtins.filterSource` via
translation to regexes. Please add give this a star iff this project proves to be useful to you.

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

This project has been included in [nixpkgs](https://github.com/NixOS/nixpkgs/) since 2019.02.18.
and it should land in the `19.03` release, so you can start using it like this:

```nix
with (import <nixpkgs> {});

let
  additionalIgnores = ''
    /this
    /that/**.html
  '';

  source = nix-gitignore.gitignoreSource additionalIgnores ./source;
in
  "use ${source} here"
```

<details>
<summary>Here's the `fetchFromGitHub` nix example if it's ever needed.</summary>

### `fetchFromGitHub` example

Replace the `rev` and `sha256` lines with the output of this command:

```bash
nix-prefetch-git https://github.com/siers/nix-gitignore 2> /dev/null | jq -r '"rev = \"\(.rev)\";\nsha256 = \"\(.sha256)\";"'
```

in this snippet:

```nix
with (import <nixpkgs> {});

let
  gitignore = callPackage (pkgs.fetchFromGitHub {
    owner = "siers";
    repo = "nix-gitignore";
    rev = "…";
    sha256 = "…";
  }) {};
in
  with gitignore;

let
  additionalIgnores = ''
    /this
    /that/**.html
  '';

  source = gitignoreSource additionalIgnores ./source;
in
  "use ${source} here"
```
</details>

## Usage

The `default.nix` exports (among other things) four functions. Three of these are:

    gitignoreSource [] ./source
        # Simplest version

    gitignoreSource "supplemental-ignores\n" ./source
        # This one reads the ./source/.gitignore and concats the auxiliary ignores

    gitignoreSourcePure "ignore-this\nignore-that\n" ./source
        # Use this string as gitignore, don't read ./source/.gitignore.

    gitignoreSourcePure ["ignore-this\nignore-that\n", ~/.gitignore] ./source
        # It also accepts a list (of strings and paths) that will be concatenated
        # once the paths are turned to strings via readFile.

They're all derived from the `Filter` functions with the first filter argument hardcoded as `(_: _: true)`:

    gitignoreSourcePure = gitignoreFilterSourcePure (_: _: true);
    gitignoreSource = gitignoreFilterSource (_: _: true);

The `filter` accepts the same arguments the `filterSource` function would pass to its filters.
Thus `fn: gitignoreFilterSourcePure fn ""` is extensionally equivalent to `filterSource`.
The file is blacklisted iff it's blacklisted by either your filter or the gitignoreFilter.

If you want to make your own filter from scratch, you may use

    gitignoreFilter = ign: root: filterPattern (gitignoreToPatterns ign) root;

#### `.gitignore` files in subdirectories

If you wish to use a filter that would search for `.gitignore` files in subdirectories,
just like git does by default, use this function.

    gitignoreFilterRecursiveSource = filter: patterns: root:
    gitignoreRecursiveSource = gitignoreFilterSourcePure (_: _: true);

## Testing

I highly recommend taking a look at the test files
[test.nix](https://github.com/siers/nix-gitignore/blob/master/test.nix) and
[test.sh](https://github.com/siers/nix-gitignore/blob/master/test.sh)
which show how closely the actual git implementation's being mimicked.
If you find any deviances, please file an issue. Even though it probably works 99% of the time,
the pattern `[^b/]har-class-pathalogic` is the only one found that doesn't work like in git.
