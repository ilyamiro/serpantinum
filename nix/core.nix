{ lib
, rustPlatform
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-core";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-core";
    rev = "v${finalAttrs.version}";
    hash = "sha256-h0jtcQAK2AYUo7198Y8bj7DZ8jSqKIrNvqX6zjepa4g=";
  };

  cargoHash = "sha256-2qbl46lSrs6xRyaT+gcKbEfzfRoymlG/3vDlquYDVBw=";

  meta = {
    description = "A core of services for Serpantinum shell in Rust";
    homepage = "https://github.com/ilyamiro/serpantinum-core";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-core";
    platforms = lib.platforms.linux;
  };
})
