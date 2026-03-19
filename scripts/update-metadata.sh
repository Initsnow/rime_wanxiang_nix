#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_file="${root_dir}/nix/metadata.nix"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

schema_api="https://api.github.com/repos/amzxyz/rime_wanxiang/releases"
gram_api="https://api.github.com/repos/amzxyz/RIME-LMDG/releases"

schema_files=(
  "base:rime-wanxiang-base.zip"
  "flypy:rime-wanxiang-flypy-fuzhu.zip"
  "hanxin:rime-wanxiang-hanxin-fuzhu.zip"
  "moqi:rime-wanxiang-moqi-fuzhu.zip"
  "tiger:rime-wanxiang-tiger-fuzhu.zip"
  "wubi:rime-wanxiang-wubi-fuzhu.zip"
  "zrm:rime-wanxiang-zrm-fuzhu.zip"
  "shouyou:rime-wanxiang-shouyou-fuzhu.zip"
)

dict_files=(
  "base:base-dicts.zip"
  "flypy:pro-flypy-fuzhu-dicts.zip"
  "hanxin:pro-hanxin-fuzhu-dicts.zip"
  "moqi:pro-moqi-fuzhu-dicts.zip"
  "tiger:pro-tiger-fuzhu-dicts.zip"
  "wubi:pro-wubi-fuzhu-dicts.zip"
  "zrm:pro-zrm-fuzhu-dicts.zip"
  "shouyou:pro-shouyou-fuzhu-dicts.zip"
)

to_sri() {
  nix hash convert --hash-algo sha256 --to sri "$1"
}

write_asset_block() {
  local kind="$1"
  shift
  local -a items=("$@")

  printf "  %s = {\n" "${kind}"
  local item key file url hash_hex hash_sri dest
  for item in "${items[@]}"; do
    key="${item%%:*}"
    file="${item#*:}"

    if [[ "${kind}" == "schema" ]]; then
      url="https://github.com/amzxyz/rime_wanxiang/releases/download/${schema_tag}/${file}"
    else
      url="https://github.com/amzxyz/rime_wanxiang/releases/download/dict-nightly/${file}"
    fi

    dest="${tmp_dir}/${file}"
    curl -fL --retry 3 --connect-timeout 10 -o "${dest}" "${url}" >/dev/null
    hash_hex="$(sha256sum "${dest}" | awk '{print $1}')"
    hash_sri="$(to_sri "${hash_hex}")"

    cat <<EOF
    ${key} = {
      file = "${file}";
      url = "${url}";
      hash = "${hash_sri}";
    };
EOF
  done
  printf "  };\n\n"
}

schema_tag="$(
  curl -fsSL "${schema_api}" |
    jq -r '[.[].tag_name | select(test("rc") | not) | select(. != "dict-nightly")] | sort_by(split(".") | map(gsub("^v"; "") | tonumber? // 0)) | last'
)"

gram_tag="$(
  curl -fsSL "${gram_api}" |
    jq -r '[.[].tag_name | select(. == "LTS")][0]'
)"

gram_file="wanxiang-lts-zh-hans.gram"
gram_url="https://github.com/amzxyz/RIME-LMDG/releases/download/${gram_tag}/${gram_file}"
gram_dest="${tmp_dir}/${gram_file}"
curl -fL --retry 3 --connect-timeout 10 -o "${gram_dest}" "${gram_url}" >/dev/null
gram_hex="$(sha256sum "${gram_dest}" | awk '{print $1}')"
gram_sri="$(to_sri "${gram_hex}")"

{
  cat <<EOF
{
  schemaVersion = "${schema_tag}";
  dictVersion = "dict-nightly";
  gramVersion = "${gram_tag}";

EOF
  write_asset_block "schema" "${schema_files[@]}"
  write_asset_block "dict" "${dict_files[@]}"
  cat <<EOF
  gram = {
    file = "${gram_file}";
    url = "${gram_url}";
    hash = "${gram_sri}";
  };
}
EOF
} > "${out_file}"

echo "Updated ${out_file}"
