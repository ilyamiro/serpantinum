{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, pipewire
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "serpantinum-audio";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-audio";
    rev = "v${finalAttrs.version}";
    hash = "sha256-orWu0sq5zXZWFKMhU8DlBA6Ghj7GtpHEefSA5DpZT6o=";
  };

  strictDeps = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ pipewire ];

  doCheck = true;
  checkTarget = "test";

  makeFlags = [ "PREFIX=$(out)" ];

  meta = {
    description = "PipeWire audio processor for the Serpantinum shell";
    homepage = "https://github.com/ilyamiro/serpantinum-audio";
    license = lib.licenses.agpl3Only;
    mainProgram = "serpantinum-audio";
    platforms = lib.platforms.linux;
  };
})
