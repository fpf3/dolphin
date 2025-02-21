# shell for dev and debug
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell rec {
    buildInputs = with pkgs.buildPackages;
    [
      xorg.xev
      xorg.libX11
      xorg.libXft
      xorg.libXinerama
      xorg.libxcb
      xorg.libXext
      xorg.libXrandr
      gdb
      clang-tools
      cmake
      pkg-config
      git
      libao
      lzo
      miniupnpc
      openal
      libpulseaudio
      readline
      soil
      soundtouch
      libusb1
      wxGTK32
      portaudio
      zlib
      libudev-zero
      libevdev
      mbedtls
      mesa
      libpng
      kdePackages.qtbase
      kdePackages.qtsvg
      alsa-lib
      libllvm
      bluez
    ];
    
    nativeBuildInputs = with pkgs; [
      gcc
      dmenu
      feh
      gnumake
      libclang
      lukesmithxyz-st
      rofimoji
    ];
    
    LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
}
