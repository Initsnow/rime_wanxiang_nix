# rime_wanxiang_nix

## 用法

### 在 `home.nix` 中使用

如果你是通过 NixOS 的 `home-manager.nixosModules.home-manager` 管理 Home Manager，推荐在 flake 里通过 `home-manager.sharedModules` 统一导入模块。

推荐写法：

```nix
{
  home-manager.sharedModules = [
    rime-wanxiang.homeManagerModules.default
  ];

  home-manager.users.initsnow = {
    imports = [ ./home.nix ];
  };
}
```

这样 `home.nix` 里只需要写：

```nix
{
  ...
}:
{
  programs.rime.wanxiang = {
    enable = true;
    inputMethod = "fcitx5";
    schema = "base";
    fuzhu = "base";
    withDict = true;
    withGram = true;
  };
}
```

最后执行：

```bash
sudo nixos-rebuild switch
```

备选写法是在 `home.nix` 里直接 import 模块：

```nix
{
  inputs,
  ...
}:
{
  imports = [
    inputs.rime-wanxiang.homeManagerModules.default
  ];

  programs.rime.wanxiang = {
    enable = true;
    inputMethod = "fcitx5";
    schema = "base";
    fuzhu = "base";
    withDict = true;
    withGram = true;
  };
}
```

这种方式要求你的 flake 已经通过 `home-manager.extraSpecialArgs = { inherit inputs; };` 把 `inputs` 传进 `home.nix`。

### 作为独立 Home Manager flake 使用

在你的 flake 里引入本仓库：

```nix
{
  inputs.rime-wanxiang.url = "github:Initsnow/rime_wanxiang_nix";

  outputs = { nixpkgs, home-manager, rime-wanxiang, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      modules = [
        rime-wanxiang.homeManagerModules.default
        ({ ... }: {
          programs.rime.wanxiang = {
            enable = true;
            inputMethod = "fcitx5";
            schema = "base";
            fuzhu = "base";
            withDict = true;
            withGram = true;
          };
        })
      ];
    };
  };
}
```

应用配置：

```bash
home-manager switch
```

如果只想构建包，也可以直接用：

```bash
nix build .#default
nix build .#wanxiang-base
```

## 行为说明

模块会在 `home-manager switch` 或 `nixos-rebuild switch` 的 Home Manager 激活阶段同步万象配置到 Rime 部署目录。

同时默认保留 `build/`、`default.yaml`、`sync/` 和常见用户数据文件，避免后续同步把已经部署好的产物和用户数据删掉。

## 选项

`programs.rime.wanxiang.enable`

启用万象方案部署。

`programs.rime.wanxiang.inputMethod`

- `"fcitx5"`
- `"ibus"`

`programs.rime.wanxiang.deployDir`

Rime 部署目录，相对 `$HOME`。不填时默认：

- `fcitx5`: `.local/share/fcitx5/rime`
- `ibus`: `.config/ibus/rime`

`programs.rime.wanxiang.schema`

- `"base"`
- `"pro"`

`programs.rime.wanxiang.fuzhu`

- `"base"`
- `"flypy"`
- `"hanxin"`
- `"moqi"`
- `"tiger"`
- `"wubi"`
- `"zrm"`
- `"shouyou"`

约束：

- `schema = "base"` 时，`fuzhu` 必须是 `"base"`
- `schema = "pro"` 时，`fuzhu` 不能是 `"base"`

`programs.rime.wanxiang.withDict`

是否安装词库。

`programs.rime.wanxiang.withGram`

是否安装语法模型。

`programs.rime.wanxiang.excludePatterns`

部署时保留的文件和目录列表，默认值：

```nix
[
  "build/"
  "custom/user_exclude_file.txt"
  "default.yaml"
  "sync/"
  "*.userdb"
  "*.custom.yaml"
  "installation.yaml"
  "user.yaml"
]
```

## 自动更新

[`scripts/update-metadata.sh`](/home/initsnow/projects/rime_wanxiang_nix/scripts/update-metadata.sh#L1) 会：

- 查询上游 release
- 下载 schema / dict / gram 资产
- 重新计算固定 hash
- 重写 [`nix/metadata.nix`](/home/initsnow/projects/rime_wanxiang_nix/nix/metadata.nix#L1)

GitHub Actions：

- [`ci.yml`](/home/initsnow/projects/rime_wanxiang_nix/.github/workflows/ci.yml#L1)：执行 `nix flake check`
- [`update-assets.yml`](/home/initsnow/projects/rime_wanxiang_nix/.github/workflows/update-assets.yml#L1)：每月 1 日和 16 日运行一次；如果 `nix/metadata.nix` 有变化且 `flake check` 通过，就自动提交到 `main`

## 测试

本地至少执行：

```bash
bash -n scripts/update-metadata.sh
nix flake check
nix build .#default
```

如果要验证 Home Manager 部署流程，再执行：

```bash
home-manager switch
```

