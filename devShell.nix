{pkgs}: let
  rootDir = "$PRJ_ROOT";

  withCategory = category: attrset:
    attrset
    // {inherit category;};

  test = name:
    withCategory "tests" {
      name = "check-${name}";
      help = "Checks ${name} testcases";
      command = ''
        set -e
        echo -e "\n\n##### Building ${name}\n"
        cd ${rootDir}/tests/${name}
        nix flake show --all-systems --allow-import-from-derivation --no-write-lock-file "$@"
        nix flake check --no-write-lock-file "$@"
      '';
    };

  dry-nixos-build = example: host:
    withCategory "dry-build" {
      name = "build-${example}-${host}";
      command = ''
        set -e
        echo -e "\n\n##### Building ${example}-${host}\n"
        cd ${rootDir}/examples/${example}
        nix flake show --all-systems --no-write-lock-file "$@"
        nix build .#nixosConfigurations.${host}.config.system.build.toplevel --no-write-lock-file --no-link "$@"
      '';
    };
in {
  name = "andromeda-shell";
  packages = with pkgs; [
    fd
    statix
    alejandra
  ];

  commands = [
    {
      command = "git rm --ignore-unmatch -f ${rootDir}/{tests,examples}/*/flake.lock";
      help = "Remove all lock files";
      name = "rm-locks";
    }
    {
      name = "fmt";
      help = "Check Nix formatting";
      command = "alejandra \${@} ${rootDir}";
    }
    {
      name = "statix-check";
      help = "Check lints and suggestions";
      command = "statix check \${@} ${rootDir}";
    }
    {
      name = "statix-fix";
      help = "Check lints and suggestions and apply fixes";
      command = "statix fix \${@} ${rootDir}";
    }

    {
      name = "evalnix";
      help = "Check Nix parsing";
      command = "fd --extension nix --exec nix-instantiate --parse --quiet {} >/dev/null";
    }
    {
      category = "dry-build";
      name = "build-darwin";
      command = "nix build ${rootDir}/examples/darwin#darwinConfigurations.Hostname1.system --no-write-lock-file --dry-run";
    }

    (test "nixosConfigurations")
    # (test "all" // {command = "check-channel-patching && check-derivation-outputs && check-hosts-config && check-overlays-flow";})

    # (dry-nixos-build "minimal-multichannel" "Hostname1")
  ];
}
