{
  description = "Andromeda Galaxy Lib";

  #**********
  #* CORE
  #**********
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils-plus = {
      url = "github:lecoqjacob/flake-utils-plus";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  #***********************
  #* DEVONLY INPUTS
  #***********************
  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Backwards compatibility
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    # Gitignore common input
    gitignore = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hercules-ci/gitignore.nix";
    };
    # Easy linting of the flake
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        gitignore.follows = "gitignore";
        flake-utils.follows = "flake-utils";
        flake-compat.follows = "flake-compat";
        nixpkgs-stable.follows = "nixpkgs-stable";
      };
    };
  };

  outputs = inputs: let
    core-inputs =
      inputs
      // {
        src = ./.;
      };

    # Create the library, extending the nixpkgs library and merging
    # libraries from other inputs
    mkLib = import ./snowfall-lib core-inputs;

    # A convenience wrapper to create the library and then call `lib.mkFlake`.
    mkFlake = flake-and-lib-options @ {
      src,
      inputs,
      snowfall ? {},
      ...
    }: let
      lib = mkLib {inherit inputs src snowfall;};
      flake-options = builtins.removeAttrs flake-and-lib-options ["inputs" "src"];
    in
      lib.mkFlake flake-options;
  in {
    inherit mkLib mkFlake;

    nixosModules = ./modules/nixos/default.nix;
    homeModules = ./modules/home/default.nix;
    darwinModules = ./modules/darwin/default.nix;

    _snowfall = rec {
      raw-config = config;

      config = {
        root = ./.;
        src = ./.;
        namespace = "snowfall";
        lib-dir = "snowfall-lib";

        meta = {
          name = "snowfall-lib";
          title = "Andromeda Galaxy Lib";
        };
      };

      internal-lib = let
        lib = mkLib {
          src = ./.;
          inputs = inputs // {self = {};};
        };
      in
        builtins.removeAttrs
        lib.snowfall
        ["internal"];
    };
  };
}
