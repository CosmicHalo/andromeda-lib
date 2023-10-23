{core-inputs, ...}: let
  inherit
    (core-inputs.nixpkgs.lib)
    mapAttrsToList
    mapAttrs
    flatten
    foldl
    recursiveUpdate
    mergeAttrs
    isDerivation
    ;
in {
  attrs = {
    merge-shallow = foldl mergeAttrs {};
    merge-deep = foldl recursiveUpdate {};
    map-concat-attrs-to-list = f: attrs: flatten (mapAttrsToList f attrs);

    ## Merge shallow for packages, but allow one deeper layer of attribute sets.
    merge-shallow-packages = items:
      foldl
      (
        result: item:
          result
          // (mapAttrs
            (
              name: value:
                if isDerivation value
                then value
                else if builtins.isAttrs value
                then (result.${name} or {}) // value
                else value
            )
            item)
      )
      {}
      items;
  };
}
