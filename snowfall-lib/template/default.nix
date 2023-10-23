{
  core-inputs,
  snowfall-lib,
  ...
}: let
  inherit (builtins) baseNameOf;
  inherit (core-inputs.nixpkgs.lib) foldl mapAttrs;

  user-templates-root = snowfall-lib.fs.get-snowfall-file "templates";
in {
  template = {
    ## Create flake templates.
    create-templates = {
      src ? user-templates-root,
      overrides ? {},
      alias ? {},
    }: let
      user-templates = snowfall-lib.fs.get-directories src;
      create-template-metadata = template: {
        name = builtins.unsafeDiscardStringContext (baseNameOf template);
        path = template;
      };

      templates-metadata = builtins.map create-template-metadata user-templates;
      merge-templates = templates: metadata:
        templates
        // {
          ${metadata.name} =
            (overrides.${metadata.name} or {})
            // {
              inherit (metadata) path;
            };
        };

      templates-without-aliases = foldl merge-templates {} templates-metadata;
      aliased-templates = mapAttrs (_name: value: templates-without-aliases.${value}) alias;
      templates = templates-without-aliases // aliased-templates // overrides;
    in
      templates;
  };
}
