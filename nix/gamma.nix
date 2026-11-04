{ lib
, rustPlatform
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-gamma";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-gamma";
    rev = "v${finalAttrs.version}";
    hash = "sha256-DRDekM8JZOLjOR+xfFyzalh/VJ/BsAsbc3StC/5CIJQ=";
  };

  cargoHash = "sha256-kIiDy5i+EZqkqz6uwg/Lt8Fk/O1Q/2kB7P/UPou8xow=";

  meta = {
    description = "Display temperature, brightness and gamma over D-Bus on Wayland";
    homepage = "https://github.com/ilyamiro/serpantinum-gamma";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-gamma";
    platforms = lib.platforms.linux;
  };
})
