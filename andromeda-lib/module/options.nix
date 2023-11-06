{lib, ...}: let
  inherit (lib) mkOption types mkEnableOption;
in rec {
  ## Create a NixOS module option.
  mkOpt = type: default: description:
    mkOption {inherit type default description;};
  ## Create a NixOS module option without a description.
  mkOpt' = type: default: mkOpt type default null;

  ######
  # Bool
  ######

  mkBoolOpt = mkOpt types.bool;
  ## Create a boolean NixOS module option without a description.
  mkBoolOpt' = mkOpt' types.bool;

  #############
  # String / Lines
  #############

  mkStrOpt = mkOpt types.str;
  ## Create a string NixOS module option without a description.
  mkStrOpt' = mkOpt' types.str;

  mkLinesOpt = mkOpt types.lines;
  ## Create a lines NixOS module option without a description.
  mkLinesOpt' = mkOpt' types.lines;

  ######
  # INT
  ######
  mkIntOpt = mkOpt types.int;
  ## Create a int NixOS module option without a description.
  mkIntOpt' = mkOpt' types.int;

  ######
  # NULL
  ######

  mkNullOpt = type: mkOpt (types.nullOr type);
  mkNullOpt' = type: mkOpt' (types.nullOr type);

  #########
  # ENABLED
  #########

  ## Create an enabled module option.
  mkEnableOpt = name: {enable = mkEnableOption name;};
  ## Create an enabled module option defaulting to true.
  mkEnableOpt' = name: {enable = mkOpt types.bool true "Whether to enable ${name}.";};

  ## Quickly enable an option.
  enabled = {enable = true;};
  ## Quickly disable an option.
  disabled = {enable = false;};
}
