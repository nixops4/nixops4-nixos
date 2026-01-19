{
  testers,
  inputs,
  nixops4-flake-in-a-bottle,
  ...
}:

testers.runNixOSTest (
  {
    lib,
    config,
    hostPkgs,
    ...
  }:
  let
    vmSystem = config.node.pkgs.hostPlatform.system;

    targetNetworkJSON = hostPkgs.writeText "target-network.json" (
      builtins.toJSON config.nodes.target.system.build.networkConfig
    );
  in
  {
    name = "nixops4-nixos";
    imports = [
      inputs.nixops4-nixos.modules.nixosTest.static
    ];

    nodes = {
      deployer =
        { pkgs, nodes, ... }:
        {
          environment.systemPackages = [
            inputs.nixops4.packages.${vmSystem}.default
            pkgs.git
          ];
          # Memory use is expected to be dominated by the NixOS evaluation, which
          # happens on the deployer.
          virtualisation.memorySize = 4096;
          virtualisation.diskSize = 10 * 1024;
          virtualisation.cores = 2;
          nix.settings = {
            substituters = lib.mkForce [ ];
            hashed-mirrors = null;
            connect-timeout = 1;
          };
          # The VM has no network access, so we pre-populate its Nix store with
          # everything needed to build the deployment's NixOS configuration.
          #
          # WHAT: We add `x.inputDerivation` for derivations similar to what the
          # deployment will build. The `inputDerivation` attribute realizes all
          # build inputs of a derivation, making them available in the store.
          #
          # WHY: The deployment's NixOS config differs from `nodes.target` (different
          # users, SSH settings, etc.), producing different derivation hashes. When
          # the VM builds these different derivations, it needs their build inputs.
          # Without network access, these must be pre-populated.
          #
          # HOW IT WORKS:
          # - `inputDerivation` is NOT transitive - it only provides immediate build inputs
          # - We add inputDerivation for high-level derivations (toplevel, checks, etc.)
          # - This brings in their build dependencies (compilers, libraries, tools)
          # - The deployment can then build its slightly-different derivations
          #
          # DEBUGGING: If the test fails trying to download sources (FODs), trace upward
          # from the FOD to find the highest-level derivation that needs building.
          # Then add that derivation's inputDerivation here. Use `nix log` on the
          # failed test to see what derivations the VM tried to build.
          #
          # Example: If openssh fails to build because cmake needs libarchive needs
          # acl needs attr.tar.gz (FOD), find what NixOS option produces the derivation
          # that needs openssh (e.g., system.checks for check-sshd-config), and add
          # its inputDerivation.
          system.extraDependencies = [
            "${inputs.flake-parts}"
            "${inputs.flake-parts.inputs.nixpkgs-lib}"
            "${inputs.nixops4}"
            "${inputs.nixops4-nixos}"
            "${inputs.nixpkgs}"
            pkgs.stdenv
            pkgs.stdenvNoCC
            pkgs.hello
            # Core system build outputs - these provide build inputs for the
            # deployment's NixOS system, which will have different hashes but
            # similar build requirements.
            nodes.target.system.build.toplevel.inputDerivation
            nodes.target.system.build.etc.inputDerivation
            nodes.target.system.path.inputDerivation
            nodes.target.system.build.bootStage1.inputDerivation
            nodes.target.system.build.bootStage2.inputDerivation
          ]
          # /etc file sources - deployment may generate different config files
          ++ lib.concatLists (
            lib.mapAttrsToList (
              k: v: if v ? source.inputDerivation then [ v.source.inputDerivation ] else [ ]
            ) nodes.target.environment.etc
          )
          # System checks (e.g., check-sshd-config) - these have build-time deps
          # like openssh that must be available when the deployment builds its
          # own checks with different configurations
          ++ map (check: check.inputDerivation) nodes.target.system.checks;
        };
      target =
        { pkgs, modulesPath, ... }:
        {
          # Test framework disables switching by default. That might be ok by itself,
          # but we also use this config for getting the dependencies in
          # `deployer.system.extraDependencies`.
          system.switch.enable = true;
          # Not used; save a large copy operation
          nix.channel.enable = false;
          nix.registry = lib.mkForce { };

          # Match the deployment's module imports to get the same dependencies
          imports = [
            (modulesPath + "/profiles/qemu-guest.nix")
            # target-vm.nix imports qemu-vm.nix for boot/filesystem config needed by
            # manual deployments. We must match it here so extraDependencies covers
            # its build inputs (kmod, etc.). NixOS test framework also imports qemu-vm.nix,
            # so this is a no-op for the test VM itself, but ensures nodes.target's
            # toplevel.inputDerivation includes the right dependencies.
            (modulesPath + "/virtualisation/qemu-vm.nix")
          ];

          # Must match target-vm.nix to get the same boot/kernel derivation hashes
          virtualisation.useBootLoader = true;

          services.openssh.enable = true;
        };
    };

    testScript = ''
      start_all()
      target.wait_for_unit("multi-user.target")
      deployer.wait_for_unit("multi-user.target")

      # This mysteriously doesn't work.
      # target.wait_for_unit("network-online.target")
      # deployer.wait_for_unit("network-online.target")

      with subtest("nix flake init"):
        deployer.succeed("""
          mkdir work
          cd work
          nix flake init --extra-experimental-features 'flakes nix-command' \
            -t ${inputs.nixops4-nixos}#default
          git init && git add -A
        """)

      with subtest("configure the deployment"):
        deployer.copy_from_host("${targetNetworkJSON}", "/root/target-network.json")
        deployer.succeed("""
          (
            cd work
            set -x
            mkdir -p ~/.ssh
            ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
            mv /root/target-network.json target-network.json
          )
        """)
        deployer_public_key = deployer.succeed("cat ~/.ssh/id_rsa.pub").strip()
        target.succeed("mkdir -p /root/.ssh && echo '{}' >> /root/.ssh/authorized_keys".format(deployer_public_key))
        host_public_key = target.succeed("ssh-keyscan target | grep -v '^#' | cut -f 2- -d ' ' | head -n 1")
        generated_config = f"""
          {{ lib, ... }}: {{
            imports = [ ./extra-deployment-config.nix ];
            resources.nixos.ssh.hostPublicKey = lib.mkForce "{host_public_key}";
            resources.nixos.nixos.module = {{
              imports = [
                (lib.modules.importJSON ./target-network.json)
              ];
            }};
          }}
          """
        deployer.succeed(f"""cat > work/generated.nix <<"_EOF_"\n{generated_config}\n_EOF_\n""")
        deployer.succeed("""
          cp ~/.ssh/id_rsa.pub work/deployer.pub
          cat -n work/generated.nix 1>&2;
          echo {} > work/extra-deployment-config.nix
          # Fail early if we made a syntax mistake in generated.nix. (following commands may be slow)
          nix-instantiate work/generated.nix --eval --parse >/dev/null
        """)

      with subtest("override the lock"):
        deployer.succeed("""
          (
            cd work
            # Add dynamically generated files to git so they're included in the store path
            git add -A
            # Commit first so the repo hash is stable before locking
            git -c user.email=test@test -c user.name=Test commit -m 'generated files'
            set -x
            nix flake lock --extra-experimental-features 'flakes nix-command' \
              --offline -v \
              --override-input flake-parts ${inputs.flake-parts} \
              --override-input nixops4-nixos ${inputs.nixops4-nixos} \
              --override-input nixops4 ${nixops4-flake-in-a-bottle} \
              --override-input nixpkgs ${inputs.nixpkgs} \
              ;
            # Commit the lock file so the git tree is clean for nixops4 apply
            git add -A
            git -c user.email=test@test -c user.name=Test commit -m 'lock file updates'
          )
        """)

      with subtest("hello is not installed before deployment"):
        target.fail("hello")

      with subtest("nixops4 apply"):
        deployer.succeed("""
          (
            cd work
            set -x
            nixops4 apply test --show-trace
          )
        """)

      with subtest("hello is installed after deployment"):
        target.succeed("""
          (
            set -x
            hello 1>&2
          )
        """)
        target.succeed("""
          (
            set -x
            cat -n /etc/greeting 1>&2
            echo "Hallo wereld" | diff /etc/greeting - 1>&2
          )
        """)

      with subtest("nixops4 apply as user"):
        extra_config = """
          { lib, ... }: {
            resources.nixos.ssh.user = "bossmang";
          }
          """
        deployer.succeed(f"""cat > work/extra-deployment-config.nix <<"_EOF_"\n{extra_config}\n_EOF_\n""")
        deployer.succeed("""
          (
            cd work
            set -x
            nixops4 apply test --show-trace
          )
        """)

      with subtest("use ssh ambient user"):
        with subtest("set up to deny root login"):
          with subtest("configure deployment to deny root login on target"):
            extra_config = """
              { lib, ... }: {
                resources.nixos.nixos.module.services.openssh.settings.PermitRootLogin = lib.mkForce "no";
              }
              """
            deployer.succeed(f"""cat > work/extra-deployment-config.nix <<"_EOF_"\n{extra_config}\n_EOF_\n""")
          with subtest("nixops4 apply"):
            deployer.succeed("""
              (
                cd work
                set -x
                nixops4 apply test --show-trace
              )
            """)
          with subtest("check assumption: root is denied"):
            deployer.succeed(f"""
              (
                set -x
                echo "target {host_public_key}" > target-host-key
                # assume pipefail semantics
                ! ( false | true )
                (
                  set +e
                  ssh -o ConnectTimeout=10 \
                      -o ConnectionAttempts=12 \
                      -o KbdInteractiveAuthentication=no \
                      -o PasswordAuthentication=no \
                      -o UserKnownHostsFile="$PWD/target-host-key" \
                      -o StrictHostKeyChecking=yes \
                      -v \
                      2>&1 \
                    target \
                    true
                  r=$?
                  echo "ssh exit status: $r" 1>&2
                  [[ $r -eq 255 ]]
                ) | tee ssh.log
                grep -F 'root@target: Permission denied (' ssh.log
                rm ssh.log
              )
            """)
          with subtest("configure user in ~/.ssh/config"):
            deployer.succeed("""
              mkdir -p ~/.ssh
              (
                echo 'Host target'
                echo '  User bossmang'
              ) > ~/.ssh/config
              cat -n ~/.ssh/config
            """)
          with subtest("check assumption: user is allowed"):
            deployer.succeed(f"""
              (
                set -x
                echo "target {host_public_key}" > target-host-key
                ssh -o ConnectTimeout=10 \
                    -o ConnectionAttempts=12 \
                    -o KbdInteractiveAuthentication=no \
                    -o PasswordAuthentication=no \
                    -o UserKnownHostsFile="$PWD/target-host-key" \
                    -o StrictHostKeyChecking=yes \
                    -v \
                    2>&1 \
                  target \
                  true
              )
            """)
          with subtest("clean up"):
            deployer.succeed("""
              rm ~/.ssh/config
            """)

        with subtest("check error propagation through resource and nixops4"):
          deployer.succeed("""
            (
              cd work
              set -x
              (
                set +e
                nixops4 apply test --show-trace 2>&1
                r=$?
                echo "nixops4 exit status: $r" 1>&2
                [[ $r -eq 1 ]]
              ) | tee nixops4.log
              grep -F 'root@target: Permission denied' nixops4.log
              rm nixops4.log
            )
          """)

        with subtest("configure user in ~/.ssh/config"):
          deployer.succeed("""
            mkdir -p ~/.ssh
            (
              echo 'Host target'
              echo '  User bossmang'
            ) > ~/.ssh/config
            cat -n ~/.ssh/config
          """)

        with subtest("configure deployment to use ambient user"):
          extra_config = """
            { lib, ... }: {
              resources.nixos.nixos.module.services.openssh.settings.PermitRootLogin = lib.mkForce "no";
              resources.nixos.ssh.user = null;
            }
            """
          deployer.succeed(f"""cat > work/extra-deployment-config.nix <<"_EOF_"\n{extra_config}\n_EOF_\n""")

        with subtest("can deploy with ambient user setting"):
          deployer.succeed("""
            (
              cd work
              set -x
              nixops4 apply test --show-trace
            )
          """)


      # TODO: nixops4 run feature, calling ssh
    '';
  }
)
