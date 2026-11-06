{ lib
, rustPlatform
, fetchFromGitHub
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "serpantinum-gamma";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-gamma";
    rev = "v${finalAttrs.version}";
    hash = "sha256-1+vPg5TvFeEAT+LEhOIAtl0qZhGlNqRx5py7vr5a+vM=";
  };

  cargoHash = "sha256-3UeKkkzuINTKjvASjxc2BvKnLcHosFryO/N81pNl+ic=";

  meta = {
    description = "Display temperature, brightness and gamma over D-Bus on Wayland";
    homepage = "https://github.com/ilyamiro/serpantinum-gamma";
    license = lib.licenses.agpl3Plus;
    mainProgram = "serpantinum-gamma";
    platforms = lib.platforms.linux;
  };
})
