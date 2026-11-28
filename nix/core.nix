{ lib
, rustPlatform
, sqlite
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-core";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-core";
    rev = "v${finalAttrs.version}";
    hash = "sha256-l90sJq4uieLaVYNKlv5qVuPsVEwTd9P1z2ZuBQZBdhg=";
  };

  buildInputs = [ sqlite ];

  cargoHash = "sha256-/KbxzrlFQnekq80rYa+z6Et4YT9H71J8XfWfJLZRijc=";

  meta = {
    description = "A core of services for Serpantinum shell in Rust";
    homepage = "https://github.com/ilyamiro/serpantinum-core";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-core";
    platforms = lib.platforms.linux;
  };
})
