thisFlake@{ self, withSystem }:

{
  config,
  lib,
  resourceProviderSystem,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options = {
    nixpkgs = mkOption {
      type =
        # Why wasn't my flake type merged :(
        types.flake or types.raw;
    };
    nixos.module = mkOption {
      type = types.deferredModule;
    };
    nixos.configuration = mkOption {
      type = types.raw;
      readOnly = true;
    };
    nixos.specialArgs = mkOption {
      type = types.raw;
      default = { };
    };
    ssh.user = mkOption {
      type = types.nullOr types.str;
      default = "root";
      description = ''
        The user name to use for the SSH connection.

        When explicitly set to `null`, the user name will be chosen by the SSH client based on its configuration, which may include the `User` directive in `~/.ssh/config` or the login name under which the `nixops4` process runs.
      '';
    };
    ssh.host = mkOption {
      type = types.str;
    };
    ssh.hostPublicKey = mkOption {
      type = types.str;
    };
    ssh.opts = mkOption {
      type = types.str;
      default = "";
    };
    copy.substituteOnDestination = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to try substitutes on the destination store when copying.
        This may be faster if the link between the local and remote machines is
        slower than the link between the remote machine and its substituters.
      '';
    };
    sudo.enable = mkOption {
      type = types.bool;
      default = config.ssh.user != "root";
      defaultText = lib.literalMD ''`false` iff `config.ssh.user` is `"root"`'';
      description = ''
        Whether to call `sudo` when applying the configuration.
        This is necessary when the user is not `root`.
      '';
    };
  };
  config = {
    nixos = {
      configuration = config.nixpkgs.lib.nixosSystem {
        modules = [
          config.nixos.module
          thisFlake.self.modules.nixos.apply
        ];
        specialArgs = config.nixos.specialArgs;
      };
    };
    inputs = {
      executable = "${thisFlake.withSystem resourceProviderSystem ({ pkgs, ... }: lib.getExe pkgs.bash)}";
      args = [
        "-c"
        # ConnectionAttempts: set a limit to avoid hanging indefinitely.
        # ConnectTimeout: TCP initiation may go unnoticed until host + network are up, or be dropped, so we need to use a timeout to avoid hanging indefinitely.
        # KbdInteractiveAuthentication: see PasswordAuthentication above
        # PasswordAuthentication: disallow password entry, because stdin is not connected. May hang indefinitely.
        # StrictHostKeyChecking: disallow unknown hosts, trust-on-first-use is undue trust, and first use happens often in a team context. This behavior could be made optional when this is a stateful resource that can remember the host key, but until then, users will have to manually add the host key to the expression.
        # UserKnownHostsFile: provide the configured host key. We shouldn't rely on the user's known_hosts file, especially in a team context.
        ''
          set -euo pipefail
          export NIX_SSHOPTS="-o ConnectTimeout=10 -o ConnectionAttempts=12 -o KbdInteractiveAuthentication=no -o PasswordAuthentication=no -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${
            # FIXME: when misconfigured, and this contains a private key, we leak it to the store
            builtins.toFile "known_hosts" ''
              ${config.ssh.host} ${config.ssh.hostPublicKey}
            ''
          } "${lib.strings.escapeShellArg "${config.ssh.opts}"}
          nix copy --to "ssh-ng://$0" "$1" --no-check-sigs --extra-experimental-features nix-command${lib.optionalString config.copy.substituteOnDestination " --substitute-on-destination"}
          ssh $NIX_SSHOPTS "$0" "${lib.optionalString config.sudo.enable "sudo "}$1/bin/apply switch"
        ''
        (lib.optionalString (config.ssh.user != null) "${config.ssh.user}@" + config.ssh.host)
        config.nixos.configuration.config.system.build.toplevel
      ];
    };
  };
}
