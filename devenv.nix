{ config, pkgs, ... }:

{
  languages.python = {
    enable = true;
    # nixpkgs-python's 3.11 alias currently resolves to 3.11.18,
    # which is not present in the cachix cache and fails to build (the mimetypes patch no longer applies).
    # Pin to 3.11.17, which is available prebuilt in the cache.
    version = "3.11.17";
    uv = {
      enable = true;
      sync.enable = true;
      sync.groups = [ "lint" ];
      # This repository is an Ansible project rather than an installable Python package (there is no src/ layout),
      # so don't try to build/install the root project while syncing dependencies.
      sync.arguments = [ "--no-install-project" ];
    };
  };
  packages = [
    pkgs.devenv
    pkgs.git
    pkgs.gh
    pkgs.act  # depences container engine, eg: docker podman ...
    pkgs.actionlint
    pkgs.gnumake
    pkgs.gcc
    pkgs.jq
  ];
  services.vault = {
    enable = true;
    package = pkgs.vault-bin;
    address = "127.0.0.1:8200";
    ui = true;
  };
  tasks."ansible:roles" = {
    exec = ''
      ansible-galaxy role install \
        -r "$DEVENV_ROOT/.ansible/requirements.yml" \
        -p "$DEVENV_ROOT/.ansible/roles"
    '';
    execIfModified = [ ".ansible/requirements.yml" ];
    before = [ "devenv:enterShell" ];
  };
  tasks."ansible:collections" = {
    exec = ''
      ansible-galaxy collection install \
        -r "$DEVENV_ROOT/.ansible/requirements.yml"
    '';
    execIfModified = [ ".ansible/requirements.yml" ];
    before = [ "devenv:enterShell" ];
  };
  env = {
    ANSIBLE_CONFIG = "${config.env.DEVENV_ROOT}/.ansible/ansible.cfg";
    # VAULT_ADDR = "http://127.0.0.1:8200";
  };
  enterShell = ''
    # export VAULT_TOKEN="$(cat .vault-token 2>/dev/null || true)"
    export SSH_PUBKEY_PATH="$HOME/.ssh/id_ed25519.pub"
  '';
}
