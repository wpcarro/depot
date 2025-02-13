args: initPath:

let
  inherit (builtins)
    attrNames
    baseNameOf
    filter
    head
    length
    listToAttrs
    map
    match
    isAttrs
    readDir;

  argsWithPath = parts: args // {
    locatedAt = parts;
  };

  # The marker is added to every set that was imported directly by
  # readTree.
  importWithMark = path: parts:
    let imported = import path (argsWithPath parts);
    in if (isAttrs imported)
      then imported // { __readTree = true; }
      else imported;

  nixFileName = file:
    let res = match "(.*)\.nix" file;
    in if res == null then null else head res;

  readTree = path: parts:
    let
      dir = readDir path;
      self = importWithMark path parts;
      joinChild = c: path + ("/" + c);

      # Import non-empty subdirectories
      filterDir = f: dir."${f}" == "directory";
      children = map (c: {
        name = c;
        value = readTree (joinChild c) (parts ++ [ c ]);
      }) (filter filterDir (attrNames dir));

      # Import Nix files
      nixFiles = filter (f: f != null) (map nixFileName (attrNames dir));
      nixChildren = map (c: let p = joinChild (c + ".nix"); in {
        name = c;
        value = importWithMark p (parts ++ [ c ]);
      }) nixFiles;
    in if dir ? "default.nix"
      then self // (listToAttrs children)
      else listToAttrs (nixChildren ++ children);
in readTree initPath [ (baseNameOf initPath) ]
