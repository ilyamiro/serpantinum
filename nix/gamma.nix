{ lib
, rustPlatform
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-gamma";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-gamma";
    rev = "v${finalAttrs.version}";
    hash = "sha256-uoDM1uF9kf4HjzfRjvgzN1/FYkdK+OByCnmbxbZaQaA=";
  };

  cargoHash = "sha256-ciCXsOrsVaL/NGjWGh02QvBu83g5M7vNVKW0R8h4tnk=";

  meta = {
    description = "Display temperature, brightness and gamma over D-Bus on Wayland";
    homepage = "https://github.com/ilyamiro/serpantinum-gamma";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-gamma";
    platforms = lib.platforms.linux;
  };
})
