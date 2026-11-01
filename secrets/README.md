# Secrets (sops-nix)

Secrets live here as `*.yaml` files whose **values** are encrypted with
[sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).
The files are safe to commit. Who can decrypt what is declared in the
repo-root `.sops.yaml`.

Each host decrypts at boot with its own `/etc/ssh/ssh_host_ed25519_key`
(sops-nix default). Your workstation decrypts with your personal age key at
`~/.config/sops/age/keys.txt`.

## Why sops-nix (and when to reconsider)

Chosen over agenix because the setup is small and the `neededForUsers`
password flow is first-class. Reconsider agenix only if the secret set stays
tiny and one-per-file forever; stay on sops-nix once services start carrying
clusters of related credentials, since one sops file can hold many values.

## One-time setup (per workstation)

```sh
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt     # back this file up safely
age-keygen -y ~/.config/sops/age/keys.txt     # prints your admin public key
```

Put that `age1...` admin key in `.sops.yaml` as `&admin`.

## Add a host

A host can't decrypt until its key is a recipient, and a new host has no SSH
host key until it's installed. So:

1. Install the host (its sops secrets just fail to decrypt on first boot).
2. Get its age key:  `ssh-keyscan -t ed25519 <host> | ssh-to-age`
3. Put it in `.sops.yaml` and add the anchor to the `creation_rules` that the
   host needs.
4. Re-key those files:  `sops updatekeys secrets/<file>.yaml`
5. Rebuild the host.

## Add a secret

- Pick the file by **recipient set**, not by topic: a secret only `europa`
  needs goes in `secrets/europa.yaml`; one every host needs goes in
  `secrets/common.yaml`. Need a different set than any existing file? Add a
  new file + `creation_rule` rather than widening an existing one.
- Edit:  `sops secrets/common.yaml`  (opens decrypted; sops re-encrypts on save)
- Reference in Nix:  `config.sops.secrets.<name>.path`

## Current secrets

| File                | Key            | Used by            | Consumed in                 |
| ------------------- | -------------- | ------------------ | --------------------------- |
| `secrets/common.yaml` | `user-password` | all hosts        | `hosts/modules/users.nix`   |
| `secrets/europa.yaml` | `smb-angerzen`  | europa           | `hosts/europa/shares.nix`   |

`user-password` is a `mkpasswd -m sha-512` hash. `smb-angerzen` is the plain
Samba password (loaded into Samba's own db by the `smb-setpw` service).

## Impermanence note

If a host ever uses impermanence, its `/etc/ssh/ssh_host_ed25519_key` MUST be
on the persisted volume — otherwise it's regenerated each boot and sops-nix
can no longer decrypt anything on that host.
