# Andromeda Lib
[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/milkyway-org/andromeda-lib/badge)](https://flakehub.com/flake/milkyway-org/andromeda-lib)

<p>
  <a href="https://nixos.wiki/wiki/Flakes" target="_blank"><img alt="Nix Flakes Ready" src="https://img.shields.io/static/v1?logo=nixos&logoColor=d8dee9&label=Nix%20Flakes&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge"></a>
  <a href="https://nixos.org" target="_blank"><img alt="Linux Ready" src="https://img.shields.io/static/v1?logo=linux&logoColor=d8dee9&label=Linux&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge"></a>
  <a href="https://github.com/lnl7/nix-darwin" target="_blank"><img alt="macOS Ready" src="https://img.shields.io/static/v1?logo=apple&logoColor=d8dee9&label=macOS&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge"></a>
  <a href="https://github.com/nix-community/nixos-generators" target="_blank"><img alt="Generators Ready" src="https://img.shields.io/static/v1?logo=linux-containers&logoColor=d8dee9&label=Generators&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge"></a>
</p>

&nbsp;

> Unified configuration for systems, packages, modules, shells, templates, and more with Nix Flakes.
>
> _Snowfall Lib is built on top of [flake-utils-plus](https://github.com/gytis-ivaskevicius/flake-utils-plus)._

This is a fork of [Snowfall Lib](https://github.com/snowfallorg/lib) with some additions and changes
to fit my personal use case.

Things added/modified:

- allow self in passed `user-inputs`
- global `specialArgs` for `homes`
- Pass inputs along with `overlays`
- Pass `isLinux` & `isDarwin` to all modules
- Merge `user-modules` with self defined `hosts` within `mkFlake`.
- Add more `option` functions to help construct `options` more easily. [Module Options](https://github.com/milkyway-org/andromeda-lib/blob/main/andromeda-lib/module/options.nix) 
- Extend `user` config to accept home options to be merged back with `home-manager`.
- Allow for multiple `@` within `homes` names => `myhome@email.com@hostname`
- Update `nixosModules`, `darwinModules`, and `homeModules` on flake to be more easily used within mkFlake.
  
## Get Started

Add andromeda-lib to your `flake.nix`:

```nix
{
  inputs.andromeda-lib.url = "https://flakehub.com/f/milkyway-org/andromeda-lib/*.tar.gz";

  outputs = { self, andromeda-lib }: {
    # Use in your outputs
  };
}

```

See the Snowfall Lib [Quickstart](https://snowfall.org/guides/lib/quickstart/) guide to start using Andromeda Lib.

## Reference

Looking for Snowfall Lib documentation? See the Snowfall Lib [Reference](https://snowfall.org/reference/lib/).
