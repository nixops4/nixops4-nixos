thisFlake@{ self, withSystem }:
{
  config,
  lib,
  resourceProviderSystem,
  providers,
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

    state.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to create a <literal>local.memo</literal> sibling resource
        (<literal>members.stateVersion</literal>) that remembers the NixOS
        <option>system.stateVersion</option> across deployments.

        This prevents accidental <literal>stateVersion</literal> drift when
        regenerating the deployment expression for an existing machine — the
        memo resource retains the value that was recorded at first deploy and
        makes it available as <literal>members.stateVersion.outputs.value</literal>.

        Disable this if you manage <option>system.stateVersion</option> explicitly
        in your NixOS configuration or if your state provider does not support
        <literal>local.memo</literal>.
      '';
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

    # The consuming module must define this option (e.g. nixos, darwin, homeManager).
    # It should be the store path of the built toplevel / activation package.
    _toplevel = mkOption {
      type = types.package;
      internal = true;
    };
  };

  config.members.apply =
    lib.optionalAttrs config.state.enable {
      stateVersion = {
        type = providers.local.memo;
        inputs.value = config._nixosConfig.config.system.stateVersion;
      };
    }
    // {
      # ConnectionAttempts: set a limit to avoid hanging indefinitely.
      # ConnectTimeout: TCP initiation may go unnoticed until host + network are up, or be dropped, so we need to use a timeout to avoid hanging indefinitely.
      # KbdInteractiveAuthentication: see PasswordAuthentication above
      # PasswordAuthentication: disallow password entry, because stdin is not connected. May hang indefinitely.
      # StrictHostKeyChecking: disallow unknown hosts, trust-on-first-use is undue trust, and first use happens often in a team context. This behavior could be made optional when this is a stateful resource that can remember the host key, but until then, users will have to manually add the host key to the expression.
      # UserKnownHostsFile: provide the configured host key. We shouldn't rely on the user's known_hosts file, especially in a team context.
      sshOptions = [
        "-o"
        "ConnectTimeout=10"
        "-o"
        "ConnectionAttempts=12"
        "-o"
        "KbdInteractiveAuthentication=no"
        "-o"
        "PasswordAuthentication=no"
        "-o"
        "StrictHostKeyChecking=yes"
        "-o"
        "UserKnownHostsFile=${
          # FIXME: when misconfigured, and this contains a private key, we leak it to the store
          builtins.toFile "known_hosts" ''
            ${config.ssh.host} ${config.ssh.hostPublicKey}
          ''
        }"
      ]
      ++ lib.optionals (config.ssh.opts != "") (lib.splitString " " config.ssh.opts);

      host = (lib.optionalString (config.ssh.user != null) "${config.ssh.user}@") + config.ssh.host;

      # Copies the toplevel closure to the target host before activating.
      copyOptions = lib.optionalAttrs config.copy.substituteOnDestination {
        substituteOnDestination = true;
      };

      # Use sudo if configured.
      sudo = config.sudo.enable;

      # The toplevel derivation to deploy.
      toplevel = config._toplevel;
    };
}
