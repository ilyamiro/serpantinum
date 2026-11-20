{ lib
, rustPlatform
, sqlite
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-core";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-core";
    rev = "v${finalAttrs.version}";
    hash = "sha256-w0dfleXgIUrUYxW6Xr4n6f0JO+jvnIEi8EljDUVQoJ8=";
  };

  buildInputs = [ sqlite ];

  cargoHash = "sha256-G2DbnZWR+eRnEkcRo4Q8MeeGDntaWRrNasWX0MOoCm4=";

  meta = {
    description = "A core of services for Serpantinum shell in Rust";
    homepage = "https://github.com/ilyamiro/serpantinum-core";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-core";
    platforms = lib.platforms.linux;
  };
})
