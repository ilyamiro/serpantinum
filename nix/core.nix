{ lib
, rustPlatform
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-core";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-core";
    rev = "v${finalAttrs.version}";
    hash = "sha256-dUlZctM/SMPZ0RTNpGDNDEOWVIBzcRXq1E8WLG1Evoc=";
  };

  cargoHash = "sha256-ljXu8t5dtiY6BEDKhW0UWo/JyFQHUq9fnLKb2I0exIs=";

  meta = {
    description = "A core of services for Serpantinum shell in Rust";
    homepage = "https://github.com/ilyamiro/serpantinum-core";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-core";
    platforms = lib.platforms.linux;
  };
})
