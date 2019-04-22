{ lib ? import <nixpkgs/lib> }:
let
  inherit (builtins) readDir readFile;
  parse-ini = import ./parse-ini.nix { inherit lib; };
in
rec {
  inherit (builtins) readDir readFile dirOf baseNameOf abort;
  inherit (lib.lists) filter length head concatMap take;
  inherit (lib.strings) hasPrefix removePrefix;
  inherit (lib) strings flip;
  inherit lib;
  inherit parse-ini;

  # TODO: filter DOS newlines at every readFile
  # TODO: check assumption that a relative core.excludesFile is relative to HOME

  #####
  # Finding the gitignore files
  #
  findAncestryGitignores = path:
    let
      up = inspectDirAndUp path;
      inherit (up) localIgnores gitDir worktreeRoot;
      globalIgnores = map (file: { contextDir = worktreeRoot; inherit file; }) maybeGlobalIgnoresFile;

      # TODO: can local config override global core.excludesFile?
      # localConfigItems = parse-ini.parseIniFile (gitDir + "/config");
    in
      globalIgnores ++ localIgnores;



  #####
  # Functions for getting "context" from directory ancestry, repo
  #

  /* path -> { localIgnores : list {contextDir, file}
             , gitDir : path }
    
     Precondition: dir exists and is a directory


   */
  inspectDirAndUp = dirPath: let
      go = p: acc:
        let
          dirInfo = inspectDir p;
          isHighest = dirInfo.isWorkTreeRoot || p == /. || p == "/";
          dirs = [dirInfo] ++ acc;

          getIgnores = di: if di.hasGitignore
            then [{ contextDir = di.dirPath; file = di.dirPath + "/.gitignore"; }]
            else [];

        in
          if isHighest
          then
            {
              localIgnores = concatMap getIgnores dirs;
              worktreeRoot = p;
              inherit (dirInfo) gitDir;
            }
          else
            go (dirOf p) dirs
      ;
    in go dirPath [];

  inspectDir = dirPath:
    let 
      d = readDir dirPath;
      dotGitType = d.".git" or null;
      isWorkTreeRoot = dotGitType != null;
      gitDir = if dotGitType == nodeTypes.directory then dirPath + "/.git"
               else if dotGitType == nodeTypes.regular then readDotGitFile (dirPath + "/.git")
               else dotGitType;
      hasGitignore = (d.".gitignore" or null) == nodeTypes.regular;
    in { inherit isWorkTreeRoot hasGitignore gitDir dirPath; };
  
  /* .git file path -> GIT_DIR

     Used for establishing $GIT_DIR when the worktree is an external worktree,
     when .git is a file.
   */
  readDotGitFile = filepath:
    let contents = readFile filepath;
        lines = lib.strings.splitString "\n" contents;
        gitdirLines = map (strings.removePrefix "gitdir: ") (filter (lib.strings.hasPrefix "gitdir: ") lines);
        errNoGitDirLine = abort ("Could not find a gitdir line in " + filepath);
    in /. + headOr errNoGitDirLine gitdirLines
  ;

  /* default -> list -> head or default
   */
  headOr = default: l:
    if length l == 0 then default else head l;



  #####
  # Finding git config
  #

  maybeXdgGitConfigFile = 
    bindList
      (guardNonEmptyString (/. + builtins.getEnv "XDG_CONFIG_HOME"))
      (xdgConfigHome:
        guardFile (xdgConfigHome + "/git/config")
      );
  maybeGlobalConfig = take 1 (guardFile ~/.gitconfig
                           ++ maybeXdgGitConfigFile
                           ++ guardFile ~/.config/git/config);

  globalConfigItems = bindList maybeGlobalConfig (globalConfigFile:
    parse-ini.parseIniFile globalConfigFile
  );
  globalConfiguredExcludesFile = take 1 (
    bindList
      globalConfigItems
      ({section, key, value}:
        bindList
          (guard (section == "core" && key == "excludesFile"))
          (_:
            resolveFile (~/.) value
          )
      )
    );
  xdgExcludesFile = bindList
    (guardNonEmptyString (/. + builtins.getEnv "XDG_CONFIG_HOME"))
    (xdgConfigHome:
      guardFile (xdgConfigHome + "/git/ignore")
    );
  maybeGlobalIgnoresFile = take 1
                            ( globalConfiguredExcludesFile
                           ++ xdgExcludesFile
                           ++ guardFile ~/.config/git/ignore);
  resolveFile = baseDir: path: take 1
    (  (if hasPrefix "/" path then guardFile (/. + path) else [])
    ++ (if hasPrefix "~" path then guardFile (~/. + removePrefix "~" path) else [])
    ++ guardFile (baseDir + "/" + path)
    )
  ;


  #####
  # List as a search and backtracking tool
  #

  nullableToList = x: if x == null then [] else [x];
  bindList = l: f: concatMap f l;
  homeGitConfigFile = guardFile ~/.gitconfig;
  guard = b: if b then [{}] else [];
  guardFile = p: if nodeTypes.isFile (safeGetNodeType p) then [p] else [];
  guardNonEmptyString = s: if s == "" then [s] else [];
  guardNonNull = a: if a != null then a else [];



  #####
  # Working with readDir output
  #

  nodeTypes.directory = "directory";
  nodeTypes.regular = "regular";
  nodeTypes.symlink = "symlink";

  # TODO: Assumes that it's a file when it's a symlink
  nodeTypes.isFile = p: p == nodeTypes.regular || p == nodeTypes.symlink;



  #####
  # Generic file system functions
  #

  /* path -> nullable nodeType
   * Without throwing (unrecoverable) errors
   */
  safeGetNodeType = path:
    if toString path == "/" then nodeTypes.directory
    else let parent = dirOf path;
             baseName = baseNameOf path;
    in if safeGetNodeType parent != nodeTypes.directory then null
    else let parentDir = readDir parent;
    in parentDir."${baseName}" or null;


}
