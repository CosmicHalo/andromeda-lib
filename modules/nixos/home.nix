{
  lib,
  inputs,
  config,
  ...
}: let
  inherit (lib) types mkIf;
  inherit (lib.snowfall.module) mkOpt mkBoolOpt;

  cfg = config.snowfallorg.home;
in {
  options.snowfallorg.home = with types; {
    stateVersion =
      mkOpt str
      "23.11" "The version of home-manager to use.";

    useGlobalPkgs = mkBoolOpt false "Whether to use global packages.";
    useUserPackages = mkBoolOpt false "Whether to use user packages.";

    modules =
      mkOpt (listOf path) []
      "Modules to import into home-manager.";

    file =
      mkOpt attrs {}
      (mdDoc "A set of files to be managed by home-manager's `home.file`.");

    configFile =
      mkOpt attrs {}
      (mdDoc "A set of files to be managed by home-manager's `xdg.configFile`.");

    extraOptions =
      mkOpt attrs {}
      "Options to pass directly to home-manager.";
  };

  config = mkIf (inputs ? home-manager) {
    snowfallorg.home.extraOptions = {
      xdg.enable = true;
      home.file = config.snowfallorg.home.file;
      home.stateVersion = cfg.stateVersion;
      xdg.configFile = config.snowfallorg.home.configFile;
    };

    home-manager = {
      inherit (cfg) useGlobalPkgs useUserPackages;

      users.${config.snowfallorg.user.name} =
        config.snowfallorg.home.extraOptions
        // {imports = config.snowfallorg.home.modules;};
    };
  };
}
