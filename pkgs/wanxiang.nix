{ lib
, stdenvNoCC
, fetchurl
, unzip
, rsync
, metadata
}:
let
  deleteFiles = [
    "README.md"
    "CHANGELOG.md"
    "version.txt"
    "custom_phrase.txt"
    "squirrel.yaml"
    "weasel.yaml"
    "简纯+.trime.yaml"
  ];

  fuzhuList = [
    "base"
    "flypy"
    "hanxin"
    "moqi"
    "tiger"
    "wubi"
    "zrm"
    "shouyou"
  ];

  unpackZip = name: asset:
    stdenvNoCC.mkDerivation {
      pname = name;
      version = "1";
      src = fetchurl {
        inherit (asset) url hash;
      };
      nativeBuildInputs = [ unzip rsync ];
      dontUnpack = true;
      installPhase = ''
        runHook preInstall

        tmpdir="$(mktemp -d)"
        unzip -q "$src" -d "$tmpdir"

        mkdir -p "$out"
        shopt -s dotglob nullglob
        entries=("$tmpdir"/*)

        if [ "''${#entries[@]}" -eq 1 ] && [ -d "''${entries[0]}" ]; then
          rsync -a "''${entries[0]}/" "$out/"
        else
          rsync -a "$tmpdir/" "$out/"
        fi

        rm -rf "$tmpdir"
        runHook postInstall
      '';
    };

  cleanedSchema = variant:
    let
      unpacked = unpackZip "wanxiang-schema-${variant}" metadata.schema.${variant};
    in
    stdenvNoCC.mkDerivation {
      pname = "wanxiang-schema-${variant}";
      version = metadata.schemaVersion;
      nativeBuildInputs = [ rsync ];
      dontUnpack = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        rsync -a "${unpacked}/" "$out/"
        chmod -R u+w "$out"
        ${lib.concatMapStringsSep "\n" (file: "rm -rf \"$out/${file}\"") deleteFiles}
        runHook postInstall
      '';
    };

  unpackedDict = variant:
    unpackZip "wanxiang-dict-${variant}" metadata.dict.${variant};

  gramFile = fetchurl {
    inherit (metadata.gram) url hash;
  };

  resolveSchemaVariant = { schema, fuzhu }:
    if schema == "base" then
      "base"
    else if schema == "pro" then
      if fuzhu == "base" then
        throw "`schema = \"pro\"` requires a non-base fuzhu"
      else
        fuzhu
    else
      throw "Unsupported schema variant: ${schema}";

  resolveDictVariant = fuzhu:
    if fuzhu == "base" then "base" else fuzhu;
in
{
  inherit metadata fuzhuList;

  mkWanxiangPackage =
    { schema ? "pro"
    , fuzhu ? "flypy"
    , withDict ? true
    , withGram ? true
    }:
    let
      schemaVariant = resolveSchemaVariant { inherit schema fuzhu; };
      dictVariant = resolveDictVariant fuzhu;
      schemaPkg = cleanedSchema schemaVariant;
      dictPkg = if withDict then unpackedDict dictVariant else null;
      packageName = lib.concatStringsSep "-" ([
        "wanxiang"
        schema
        fuzhu
      ] ++ lib.optionals withDict [ "dict" ] ++ lib.optionals withGram [ "gram" ]);
    in
    stdenvNoCC.mkDerivation {
      pname = packageName;
      version = metadata.schemaVersion;
      nativeBuildInputs = [ rsync ];
      dontUnpack = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        rsync -a "${schemaPkg}/" "$out/"
        chmod -R u+w "$out"
        ${lib.optionalString withDict ''
          mkdir -p "$out/dicts"
          rsync -a "${dictPkg}/" "$out/dicts/"
        ''}
        ${lib.optionalString withGram ''
          cp "${gramFile}" "$out/${metadata.gram.file}"
        ''}
        runHook postInstall
      '';
    };
}
