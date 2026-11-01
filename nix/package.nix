{ lib
, stdenv
, callPackage
, makeWrapper
, wrapGAppsHook3
, python3
, gtk3
, qt5
, qt6
, acpi
, adw-gtk3
, alsa-utils
, bc
, bluez
, brightnessctl
, ddcutil
, cava
, cliphist
, fastfetch
, fd
, ffmpeg
, file
, gpu-screen-recorder
, grim
, imagemagick
, inotify-tools
, iw
, jq
, kitty
, libnotify
, lm_sensors
, matugen
, networkmanager
, pamixer
, pavucontrol
, pciutils
, playerctl
, power-profiles-daemon
, psmisc
, ripgrep
, satty
, slurp
, socat
, util-linux
, wf-recorder
, wget
, wireplumber
, wl-clipboard
, wl-gammarelay-rs
, wmctrl
, xdg-desktop-portal-gtk
, tesseract
, zbar
, quickshell
, libpulseaudio
, pipewire
, serpantinum-audio ? callPackage ./audio.nix { }
, ...
}:
let
  pname = "serpantinum";
  version = lib.strings.trim (builtins.readFile ../version.txt);
  pythonEnv = python3.withPackages (ps: [ ps.websockets ps.dbus-python ps.pygobject3 ]);
  pythonEnv = python3.withPackages (ps: [ ps.websockets ps.jeepney ]);
  pathDeps = [
    acpi
    alsa-utils
    bc
    bluez
    brightnessctl
    ddcutil
    cava
    cliphist
    fastfetch
    fd
    ffmpeg
    file
    gpu-screen-recorder
    grim
    imagemagick
    inotify-tools
    iw
    jq
    kitty
    libnotify
    lm_sensors
    matugen
    networkmanager
    pamixer
    pavucontrol
    pciutils
    playerctl
    power-profiles-daemon
    psmisc
    pythonEnv
    ripgrep
    satty
    slurp
    socat
    util-linux
    wf-recorder
    wget
    wireplumber
    wl-clipboard
    wl-gammarelay-rs
    wmctrl
    xdg-desktop-portal-gtk
    tesseract
    zbar
    quickshell
    serpantinum-audio
  ];
  qtDeps = [
    quickshell
    qt6.qtwayland
    qt6.qtmultimedia
    qt6.qt5compat
    qt6.qtwebsockets
  ];
  qmlImportPath = lib.concatMapStringsSep ":" (pkg: "${pkg}/lib/qt-6/qml") qtDeps;
  qtPluginPath = lib.concatMapStringsSep ":" (pkg: "${pkg}/lib/qt-6/plugins") qtDeps;
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions (
      map (p: ../. + "/${p}") [ "bin" "src" "config" "compositors" "packaging/desktop" "version.txt" ]
    );
  };
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook wrapGAppsHook3 ];
  buildInputs = qtDeps ++ [ libpulseaudio pipewire gtk3 ];
  dontConfigure = true;
  dontBuild = true;
  dontWrapQtApps = true;
  dontWrapGApps = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/${finalAttrs.pname}"
    cp -r src/. "$out/share/${finalAttrs.pname}/"
    rm -f "$out/share/${finalAttrs.pname}/version.txt"
    cp -r config "$out/share/${finalAttrs.pname}/config"
    cp version.txt "$out/share/${finalAttrs.pname}/version.txt"
    find "$out/share/${finalAttrs.pname}" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
    install -Dm644 packaging/desktop/serpantinum-settings.desktop "$out/share/applications/serpantinum-settings.desktop"
    substituteInPlace "$out/share/applications/serpantinum-settings.desktop" \
      --replace-fail "Exec=serpantinum settings" "Exec=$out/bin/serpantinum settings"
    install -Dm644 packaging/desktop/serpantinum-settings.svg "$out/share/icons/hicolor/scalable/apps/serpantinum-settings.svg"
    install -Dm755 bin/serpantinum  "$out/bin/.serpantinum-wrapped"
    install -Dm755 bin/serpantinumd "$out/bin/.serpantinumd-wrapped"
    ln -s "${lib.getExe serpantinum-audio}" "$out/bin/serpantinum-audio"
    runHook postInstall
  '';
  postFixup = ''
    for bin in serpantinum serpantinumd; do
      makeWrapper "$out/bin/.$bin-wrapped" "$out/bin/$bin" \
        "''${qtWrapperArgs[@]}" \
        "''${gappsWrapperArgs[@]}" \
        --prefix QML2_IMPORT_PATH : "${qmlImportPath}" \
        --prefix QT_PLUGIN_PATH : "${qtPluginPath}" \
        --set SERPANTINUM_DIR "$out/share/${finalAttrs.pname}" \
        --set SERPANTINUM_VERSION "${finalAttrs.version}" \
        --prefix PATH : "${lib.makeBinPath pathDeps}"
    done
  '';
  passthru = { inherit pathDeps qtDeps pythonEnv serpantinum-audio; };
  meta = with lib; {
    description = "A desktop shell built for YOU";
    homepage = "https://github.com/ilyamiro/serpantinum";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "serpantinum";
  };
})
