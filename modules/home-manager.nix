{ config, lib, pkgs, ... }:
let
  wanxiang = pkgs.callPackage ../pkgs/wanxiang.nix {
    metadata = import ../nix/metadata.nix;
  };
  cfg = config.programs.rime.wanxiang;
  deployDir =
    if cfg.deployDir != null then
      cfg.deployDir
    else if cfg.inputMethod == "ibus" then
      ".config/ibus/rime"
    else
      ".local/share/fcitx5/rime";
  package = wanxiang.mkWanxiangPackage {
    inherit (cfg) schema fuzhu;
    withDict = cfg.withDict;
    withGram = cfg.withGram;
  };
  excludeFile = pkgs.writeText "wanxiang-rsync-excludes" (
    lib.concatStringsSep "\n" cfg.excludePatterns + "\n"
  );
in
{
  options.programs.rime.wanxiang = {
    enable = lib.mkEnableOption "declarative Rime Wanxiang deployment";

    inputMethod = lib.mkOption {
      type = lib.types.enum [ "fcitx5" "ibus" ];
      default = "fcitx5";
      description = "Which Linux Rime frontend owns the deployment directory.";
    };

    deployDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = ".local/share/fcitx5/rime";
      description = "Relative path under $HOME for the target Rime deployment directory.";
    };

    schema = lib.mkOption {
      type = lib.types.enum [ "base" "pro" ];
      default = "pro";
      description = "Schema family.";
    };

    fuzhu = lib.mkOption {
      type = lib.types.enum wanxiang.fuzhuList;
      default = "flypy";
      description = "Auxiliary code variant. Must be `base` when `schema = \"base\"`.";
    };

    withDict = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the upstream dict bundle.";
    };

    withGram = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the upstream grammar model.";
    };

    excludePatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "custom/user_exclude_file.txt"
        "*.userdb"
        "*.custom.yaml"
        "installation.yaml"
        "user.yaml"
      ];
      description = "Files preserved during rsync deployment.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.schema == "base" && cfg.fuzhu != "base");
        message = "programs.rime.wanxiang: `schema = \"base\"` requires `fuzhu = \"base\"`.";
      }
      {
        assertion = !(cfg.schema == "pro" && cfg.fuzhu == "base");
        message = "programs.rime.wanxiang: `schema = \"pro\"` requires a non-base `fuzhu`.";
      }
    ];

    home.activation.deployRimeWanxiang = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      target="${config.home.homeDirectory}/${deployDir}"
      mkdir -p "$target"
      ${pkgs.rsync}/bin/rsync -a --delete --exclude-from="${excludeFile}" "${package}/" "$target/"
    '';
  };
}
