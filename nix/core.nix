{ lib
, rustPlatform
, sqlite
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-core";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-core";
    rev = "v${finalAttrs.version}";
    hash = "sha256-JC3lhOBqUbDX0jHA7y0EZkDwGwNpUFZ4ZDhxumJudMM=";
  };

  buildInputs = [ sqlite ];

  cargoHash = "sha256-uqcgSz2AawX+Ya66qUZqMuvFJ+K43+lU9jJ2WAAMD4M=";

  meta = {
    description = "A core of services for Serpantinum shell in Rust";
    homepage = "https://github.com/ilyamiro/serpantinum-core";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-core";
    platforms = lib.platforms.linux;
  };
})
