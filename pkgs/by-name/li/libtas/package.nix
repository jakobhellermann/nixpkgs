{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch2,
  autoreconfHook,
  pkg-config,
  SDL2,
  alsa-lib,
  ffmpeg,
  lua5_4,
  qt5,
  libxi,
  file,
  binutils,
  libcap,

  # Forces libTAS to run in X11.
  # Enabled by default because libTAS does not support Wayland.
  withForceX11 ? true,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libtas";
  version = "1.4.8";

  src = fetchFromGitHub {
    owner = "clementgallet";
    repo = "libTAS";
    rev = "v${finalAttrs.version}";
    hash = "sha256-2b+Cqzk3VDhBV+Wke37z6VrVymavZq3xGiJDY9uQ5G4=";
  };

  patches = [
    # Don't assume location to llavapipe ICD
    ./select-lavapipe-icd.patch
    # Preserve errno around isatty so hook logging stays transparent to the game
    ./preserve-errno-in-logging.patch
  ];

  postPatch = ''
    # don't try to setcap in a nix builder
    substituteInPlace src/program/Makefile.am \
      --replace-fail 'if command -v setcap >/dev/null 2>&1; then setcap cap_checkpoint_restore+eip $(DESTDIR)$(bindir)/$(bin_PROGRAMS); fi' 'true'
  '';

  nativeBuildInputs = [
    autoreconfHook
    qt5.wrapQtAppsHook
    pkg-config
  ];
  buildInputs = [
    SDL2
    alsa-lib
    ffmpeg
    lua5_4
    qt5.qtbase
    libcap
  ];

  configureFlags = [
    "--enable-release-build"
  ];

  postInstall = ''
    mkdir -p $out/lib
    mv $out/bin/libtas*.so $out/lib/
  '';

  enableParallelBuilding = true;

  postFixup = ''
    wrapProgram $out/bin/libTAS \
      --suffix PATH : ${
        lib.makeBinPath [
          file
          binutils
          ffmpeg
        ]
      } \
      --suffix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libxi
          ffmpeg.lib
        ]
      } \
      ${lib.optionalString withForceX11 "--set QT_QPA_PLATFORM xcb"} \
      --set-default LIBTAS_SO_PATH $out/lib/libtas.so
  '';

  meta = {
    homepage = "https://clementgallet.github.io/libTAS/";
    changelog = "https://github.com/clementgallet/libTAS/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    description = "GNU/Linux software to give TAS tools to games";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ skyrina jakobhellermann ];
    mainProgram = "libTAS";
    platforms = [
      "i686-linux"
      "x86_64-linux"
    ];
  };
})
