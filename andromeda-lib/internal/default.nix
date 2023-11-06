{
  core-inputs,
  user-inputs,
  andromeda-lib,
  andromeda-config,
  ...
}: let
  inherit (core-inputs.nixpkgs.lib) fix filterAttrs callPackageWith;

  core-inputs-libs = andromeda-lib.flake.get-libs (andromeda-lib.flake.without-self core-inputs);
  user-inputs-libs = andromeda-lib.flake.get-libs (andromeda-lib.flake.without-self user-inputs);

  andromeda-top-level-lib = filterAttrs (_name: value: !builtins.isAttrs value) andromeda-lib;

  base-lib = andromeda-lib.attrs.merge-shallow [
    core-inputs.nixpkgs.lib
    core-inputs-libs
    user-inputs-libs
    andromeda-top-level-lib
    {andromeda = andromeda-lib;}
  ];

  user-lib-root = andromeda-lib.fs.get-file "lib";
  user-lib-modules = andromeda-lib.fs.get-default-nix-files-recursive user-lib-root;

  user-lib = fix (
    user-lib: let
      attrs = {
        inputs = andromeda-lib.flake.without-andromeda-inputs user-inputs;
        andromeda-inputs = core-inputs;
        lib = andromeda-lib.attrs.merge-shallow [
          base-lib
          {"${andromeda-config.namespace}" = user-lib;}
        ];
      };
      libs =
        builtins.map
        (path: callPackageWith attrs path {})
        user-lib-modules;
    in
      andromeda-lib.attrs.merge-deep libs
  );

  system-lib = andromeda-lib.attrs.merge-shallow [
    base-lib
    {"${andromeda-config.namespace}" = user-lib;}
  ];
in {
  internal = {
    inherit system-lib user-lib;
  };
}
