{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, pipewire
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "serpantinum-audio";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-audio";
    rev = "v${finalAttrs.version}";
    hash = "sha256-lG01hs2rCee2sKFWyWN3V4Z14eAbuFNyGq8UHbD7K6g=";
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
