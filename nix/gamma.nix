{ lib
, rustPlatform
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-gamma";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-gamma";
    rev = "v${finalAttrs.version}";
    hash = "sha256-duMN/xE1OAmGk2iKi1fHbD5G42ILs+ruTHwXqqUyFFY=";
  };

  cargoHash = "sha256-sAdQ3B4L2M0wVSLeUMHIMeOzt9aBy9tZH+G+paUpYwg=";

  meta = {
    description = "Display temperature, brightness and gamma over D-Bus on Wayland";
    homepage = "https://github.com/ilyamiro/serpantinum-gamma";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-gamma";
    platforms = lib.platforms.linux;
  };
})
