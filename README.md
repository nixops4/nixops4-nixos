# `nixops4-nixos`

This repository provides a [NixOps4] integration for deploying NixOS configurations to existing NixOS hosts.

> [!WARNING]
> This is pre-release software. Features and functionality are subject to change.

> [!NOTE]
> This is not representative of the final product, which should include convenience options for defining hosts without manually specifying resource definitions.

## Test Drive

Try deploying to a local QEMU VM:

Initialize from template:

```bash
mkdir my-deployment && cd my-deployment
nix flake init -t github:nixops4/nixops4-nixos
git init && git add -A
```

Generate SSH key:

```bash
ssh-keygen -t ed25519 -f deployer-key -N "" -C "deployer"
cp deployer-key.pub deployer.pub
git add deployer.pub
```

Start the VM (in a separate terminal):

```bash
nix run '.#vm'
```

Get the VM's host key and update `deployment.nix`:

```bash
ssh-keyscan -t ed25519 -p 2222 127.0.0.1
# Copy the ssh-ed25519 key to deployment.nix: ssh.hostPublicKey = "..."
```

Deploy:

```bash
nix develop --command nixops4 apply default
```

Verify:

```bash
ssh -i deployer-key -p 2222 root@127.0.0.1 'cat /etc/greeting'
# Output: Hallo wereld
```

Cleanup: stop the VM (Ctrl+C in VM terminal), then:

```bash
rm nixos.qcow2
ssh-keygen -R '[127.0.0.1]:2222'
```

<!-- markdown links -->
[NixOps4]: https://nixops.dev
