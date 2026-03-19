# rime_wanxiang_nix

## 用法

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
            schema = "pro";
            fuzhu = "flypy";
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
- `"pure"`
- `"pro"`

说明：当前 `pure` 暂时复用 `base` 的上游资产。

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

部署时保留的文件列表，默认值：

```nix
[
  "custom/user_exclude_file.txt"
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
