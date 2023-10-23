{lib, ...}: let
  inherit (lib) mkOption types mkEnableOption;
in rec {
  ## Create a NixOS module option.
  mkOpt = type: default: description: mkOption {inherit type default description;};

  ## Create a NixOS module option without a default.
  mkNullOpt = type: description: mkOpt type null description;

  ## Create a NixOS module option without a default and description.
  mkNullOpt' = type: mkOpt type null null;

  ## Create a NixOS module option without a description.
  mkOpt' = type: default: mkOpt type default null;

  ## Create a boolean NixOS module option.
  #@ Type -> Any -> String
  mkBoolOpt = mkOpt types.bool;

  ## Create a boolean NixOS module option without a description.
  mkBoolOpt' = mkOpt' types.bool;

  ## Create an enabled module option.
  mkEnableOpt = name: {
    enable = mkEnableOption name;
  };

  ## Create an enabled module option defaulting to true.
  mkEnableOpt' = name: {
    enable = mkOpt types.bool true "Whether to enable ${name}.";
  };

  enabled = {
    ## Quickly enable an option.
    enable = true;
  };

  disabled = {
    ## Quickly disable an option.
    enable = false;
  };
}
