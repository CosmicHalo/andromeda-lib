{lib, ...}: let
  inherit (lib) types;
  inherit (lib.andromeda.module) mkOpt;
in {
  options.andromeda.home = with types; {
    stateVersion =
      mkOpt str "23.11"
      "The version of home-manager to use.";

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
}
