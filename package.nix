{
  stdenv,
  makeBinaryWrapper,
  removeReferencesTo,
  srcOnly,
  python3,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  fetchFromGitHub,
  nodejs_22,
  vips,
  pkg-config,
  nixosTests,
  lib,
  nix-update-script,
  cctools,
}:

let
  # build failure against better-sqlite3, so we use nodejs_22; upstream
  # bluesky-pds uses 20
  nodejs = nodejs_22;
  nodeSources = srcOnly nodejs;
  pythonEnv = python3.withPackages (p: [ p.setuptools ]);
in

stdenv.mkDerivation (finalAttrs: {
  pname = "pds";
  version = "unstable";

  src = ./service;

  nativeBuildInputs = [
    makeBinaryWrapper
    nodejs
    pythonEnv
    pkg-config
    pnpmConfigHook
    pnpm
    removeReferencesTo
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools.libtool
  ];

  # Required for `sharp` NPM dependency
  buildInputs = [ vips ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 3;
    hash = "";
  };

  buildPhase = ''
    runHook preBuild

    pushd ./node_modules/.pnpm/better-sqlite3@*/node_modules/better-sqlite3
    npm run build-release --offline --nodedir="${nodeSources}"
    find build -type f -exec remove-references-to -t "${nodeSources}" {} \;
    popd

    makeWrapper "${lib.getExe nodejs}" "$out/bin/pds" \
      --add-flags --enable-source-maps \
      --add-flags "$out/lib/pds/index.js" \
      --set-default NODE_ENV production

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/pds}
    mv node_modules $out/lib/pds
    mv index.js $out/lib/pds

    runHook postInstall
  '';

  passthru = {
    tests = lib.optionalAttrs stdenv.hostPlatform.isLinux { inherit (nixosTests) bluesky-pds; };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Bluesky Personal Data Server (PDS)";
    homepage = "https://github.com/bluesky-social/pds";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ isabelroses ];
    platforms = lib.platforms.unix;
    mainProgram = "pds";
  };
})
