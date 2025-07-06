{ pkgs, ... }:
let
  sha256 = "sha256-D/f/x8fv29O9rxJ/TuYc0myI/TDORkF88QwTkoZXXbg=";
  irohVersion = "v0.35.0";

  src = pkgs.fetchFromGitHub {
    owner = "n0-computer";
    repo = "iroh";
    tag = irohVersion;
    sha256 = sha256;
  };
in
  pkgs.rustPlatform.buildRustPackage {
    version = irohVersion;
    src = src;
    cargoLock = {
      lockFile = "${src}/Cargo.lock";
    };
    doCheck = false;
    meta = with pkgs.lib; {
      homepage = "https://github.com/n0-computer/iroh";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
      description = "Iroh";
    };
    cargoBuildFlags = [ "--features" "server" ];
    pname = "iroh";
  }