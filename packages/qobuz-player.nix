{
  lib,
  pkgs,
  ...
}:
pkgs.rustPlatform.buildRustPackage (finalAttrs: {
  pname = "qobuz-player";
  version = "0.7.2";

  src = pkgs.fetchFromGitHub {
    owner = "SofusA";
    repo = "qobuz-player";
    tag = "v${finalAttrs.version}";
    hash = "sha256-LStCoBr3BblXRpuno+QKxyJstvrNmP+wub61491NkPY=";
  };

  cargoHash = "sha256-6fUwZkXurjV9yM2Mur0lAkgFxTAEmt92DFKzbPj3Vo4=";

  nativeBuildInputs = with pkgs; [
    pkg-config
    protobuf
  ];

  buildInputs = with pkgs; [
    alsa-lib
    openssl
  ];

  meta = {
    description = "Tui, web and rfid player for Qobuz";
    homepage = "https://github.com/SofusA/qobuz-player";
    changelog = "https://github.com/SofusA/qobuz-player/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [
      jorritvanderheide
    ];
    platforms = lib.platforms.linux;
    mainProgram = "qobuz-player";
  };
})
