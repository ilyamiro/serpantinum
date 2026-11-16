{ lib
, rustPlatform
, sqlite
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-core";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-core";
    rev = "v${finalAttrs.version}";
    hash = "sha256-+k+Dn1XrM7IoJv4Sdaaul0MIzlOB1b4Lq/fuo3daoVc=";
  };

  buildInputs = [ sqlite ];

  cargoHash = "sha256-Gyg0DtDoRllkyNuSWZviTy2KBaMibRx+MkQe6lNypC8=";

  meta = {
    description = "A core of services for Serpantinum shell in Rust";
    homepage = "https://github.com/ilyamiro/serpantinum-core";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-core";
    platforms = lib.platforms.linux;
  };
})
