#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_file="${root_dir}/nix/metadata.nix"

schema_api="https://api.github.com/repos/amzxyz/rime_wanxiang/releases"
gram_api="https://api.github.com/repos/amzxyz/RIME-LMDG/releases"
github_api_header="X-GitHub-Api-Version: 2022-11-28"

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

normalize_version() {
  echo "$1" | tr -d ':-' | tr 'T' '-' | tr 'Z' 'Z'
}

digest_to_sri() {
  local digest="$1"
  local algo="${digest%%:*}"
  local hash_hex="${digest#*:}"

  if [[ "${algo}" != "sha256" ]]; then
    echo "Unsupported digest algorithm: ${digest}" >&2
    exit 1
  fi

  to_sri "${hash_hex}"
}

write_asset() {
  local api_json="$1"
  local file="$2"
  local asset_json asset_url asset_digest hash_sri

  asset_json="$(
    jq -cer --arg file "${file}" '.assets[] | select(.name == $file)' <<<"${api_json}"
  )"
  asset_url="$(jq -r '.url' <<<"${asset_json}")"
  asset_digest="$(jq -r '.digest' <<<"${asset_json}")"

  if [[ -z "${asset_digest}" || "${asset_digest}" == "null" ]]; then
    echo "Missing digest for ${file}" >&2
    exit 1
  fi

  hash_sri="$(digest_to_sri "${asset_digest}")"

  cat <<EOF
      file = "${file}";
      url = "${asset_url}";
      hash = "${hash_sri}";
      curlOptsList = [
        "-H"
        "Accept: application/octet-stream"
        "-H"
        "${github_api_header}"
      ];
EOF
}

write_asset_block() {
  local api_json="$1"
  local kind="$2"
  shift 2
  local -a items=("$@")

  printf "  %s = {\n" "${kind}"
  local item key file
  for item in "${items[@]}"; do
    key="${item%%:*}"
    file="${item#*:}"
    printf "    %s = {\n" "${key}"
    write_asset "${api_json}" "${file}"
    printf "    };\n"
  done
  printf "  };\n\n"
}

schema_release_json="$(
  curl -fsSL -H "${github_api_header}" "${schema_api}" |
    jq -cer '[.[] | select(.tag_name != "dict-nightly") | select(.tag_name != "apk") | select(.prerelease | not) | select(.draft | not)] | sort_by(.published_at) | last'
)"
schema_tag="$(jq -r '.tag_name' <<<"${schema_release_json}")"

dict_release_json="$(
  curl -fsSL -H "${github_api_header}" "${schema_api}/tags/dict-nightly"
)"
dict_version="release-$(jq -r '.id' <<<"${dict_release_json}")-$(normalize_version "$(jq -r '.updated_at' <<<"${dict_release_json}")")"

gram_release_json="$(
  curl -fsSL -H "${github_api_header}" "${gram_api}/tags/LTS"
)"
gram_file="wanxiang-lts-zh-hans.gram"
gram_asset_json="$(
  jq -cer --arg file "${gram_file}" '.assets[] | select(.name == $file)' <<<"${gram_release_json}"
)"
gram_version="asset-$(jq -r '.id' <<<"${gram_asset_json}")"
gram_url="$(jq -r '.url' <<<"${gram_asset_json}")"
gram_sri="$(digest_to_sri "$(jq -r '.digest' <<<"${gram_asset_json}")")"

{
  cat <<EOF
{
  schemaVersion = "${schema_tag}";
  dictVersion = "${dict_version}";
  gramVersion = "${gram_version}";

EOF
  write_asset_block "${schema_release_json}" "schema" "${schema_files[@]}"
  write_asset_block "${dict_release_json}" "dict" "${dict_files[@]}"
  cat <<EOF
  gram = {
    file = "${gram_file}";
    url = "${gram_url}";
    hash = "${gram_sri}";
    curlOptsList = [
      "-H"
      "Accept: application/octet-stream"
      "-H"
      "${github_api_header}"
    ];
  };
}
EOF
} > "${out_file}"

echo "Updated ${out_file}"
