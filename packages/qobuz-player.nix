{ pkgs, ... }:
pkgs.rustPlatform.buildRustPackage rec {
  pname = "qobuz-player";
  version = "0.5.1";

  src = pkgs.fetchFromGitHub {
    owner = "SofusA";
    repo = "qobuz-player";
    rev = "v${version}";
    sha256 = "+595P2V9/IKFn/dr5+JYTgwM6hTGdO6oMldBrLexta4=";
  };

  cargoHash = "sha256-SOh4nTSi6bpbMLez1ufhEt5jS4QduVWk4LpCx1UA8Mo=";

  nativeBuildInputs = with pkgs; [
    dbus
    pkg-config
    sqlite
  ];

  buildInputs = with pkgs; [
    alsa-lib
    dbus
    openssl
    sqlite
  ];

  # Disable building the web UI
  patchPhase = ''
    substituteInPlace Cargo.toml \
      --replace "qobuz-player-web" ""
  '';
}
