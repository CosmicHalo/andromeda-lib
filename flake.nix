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
    inherit (inputs.flake-utils.lib) defaultSystems eachSystemMap;

    core-inputs =
      inputs
      // {
        src = ./.;
      };

    # Create the library, extending the nixpkgs library and merging
    # libraries from other inputs
    mkLib = import ./andromeda-lib core-inputs;

    # A convenience wrapper to create the library and then call `lib.mkFlake`.
    mkFlake = flake-and-lib-options @ {
      src,
      inputs,
      andromeda ? {},
      ...
    }: let
      lib = mkLib {inherit inputs src andromeda;};
      flake-options = builtins.removeAttrs flake-and-lib-options ["inputs" "src"];
    in
      lib.mkFlake flake-options;
  in {
    lib =
      inputs.flake-utils-plus.lib
      // {
        inherit mkLib mkFlake;
      };

    nixosModules = ./modules/nixos/default.nix;
    homeModules = ./modules/home/default.nix;
    darwinModules = ./modules/darwin/default.nix;

    _andromeda = rec {
      raw-config = config;

      config = {
        root = ./.;
        src = ./.;
        namespace = "andromeda";
        lib-dir = "andromeda-lib";

        meta = {
          name = "andromeda-lib";
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
        lib.andromeda
        ["internal"];
    };

    devShell = eachSystemMap defaultSystems (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [inputs.devshell.overlays.default];
      };
    in
      pkgs.devshell.mkShell (import ./devShell.nix {inherit pkgs;}));
  };
}
