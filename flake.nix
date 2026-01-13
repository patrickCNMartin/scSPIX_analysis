{
  description = "SPIX Analysis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-22-11.url = "github:NixOS/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
    spix.url = "github:whistle-ch0i/SPIX";
    spix.flake = false;
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-22-11, flake-utils, spix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgsStable = import nixpkgs-stable { inherit system; };
        pkgsOld = import nixpkgs-22-11 { inherit system; };

        # Helper function to create a Python environment using nix + uv
        mkUvPythonEnv = { pythonPkgs, projectName, nixpkgs ? pkgs }:
          nixpkgs.stdenv.mkDerivation {
            name = "${projectName}-env";
            src = ./.;

            buildInputs = [
              pythonPkgs
              nixpkgs.uv
            ];

            phases = [ "unpackPhase" "buildPhase" "installPhase" ];

            buildPhase = ''
              export HOME=$(mktemp -d)
              cd uv-projects/${projectName}
              ${pythonPkgs}/bin/python -m venv $HOME/.venv
              export PATH="$HOME/.venv/bin:$PATH"
              ${nixpkgs.uv}/bin/uv sync
              cd - > /dev/null
            '';

            installPhase = ''
              mkdir -p $out
              cp -r $HOME/.venv/* $out/
            '';
          };

        # Environment definitions
        spixEnv = mkUvPythonEnv {
          pythonPkgs = pkgs.python312;
          projectName = "spix";
          inherit pkgs;
        };

        spixEnvStable = mkUvPythonEnv {
          pythonPkgs = pkgsStable.python312;
          projectName = "spix";
          nixpkgs = pkgsStable;
        };

        stereopyEnv = mkUvPythonEnv {
          pythonPkgs = pkgsOld.python38;
          projectName = "stereopy";
          nixpkgs = pkgsOld;
        };

        visiumhdZarrEnv = mkUvPythonEnv {
          pythonPkgs = pkgsStable.python312;
          projectName = "visiumhd-zarr";
          nixpkgs = pkgsStable;
        };

        # ==============================================================================
        # OCI IMAGES
        # ==============================================================================

        spixImage = pkgsStable.dockerTools.buildLayeredImage {
          name = "spix";
          tag = "v0.0.1";
          contents = [
            spixEnvStable
            pkgsStable.python312
            pkgsStable.bash
            pkgsStable.coreutils
            pkgsStable.findutils
            pkgsStable.gnugrep
            pkgsStable.gnused
            pkgsStable.git
            pkgsStable.curl
            pkgsStable.wget
            pkgsStable.gcc
            pkgsStable.gnumake
            pkgsStable.binutils
            pkgsStable.pkg-config
            pkgsStable.zlib
            pkgsStable.bzip2
            pkgsStable.openssl
            pkgsStable.libffi
            pkgsStable.ncurses
            pkgsStable.readline
          ];
          config = {
            Cmd = [ "${pkgsStable.python312}/bin/python3" ];
            WorkingDir = "/";
            Env = [
              "PATH=${spixEnvStable}/bin:${pkgsStable.lib.makeBinPath [ pkgsStable.bash pkgsStable.coreutils ]}"
              "PYTHONPATH=${spixEnvStable}/lib/${pkgsStable.python312.libPrefix}/site-packages"
              "PYTHONUNBUFFERED=1"
              "LD_LIBRARY_PATH=${pkgsStable.lib.makeLibraryPath [ pkgsStable.zlib pkgsStable.bzip2 pkgsStable.openssl pkgsStable.libffi pkgsStable.ncurses ]}"
            ];
          };
        };

        stereopyImage = pkgsOld.dockerTools.buildLayeredImage {
          name = "stereopy";
          tag = "v0.0.1";
          contents = [
            stereopyEnv
            pkgsOld.python38
            pkgsOld.bash
            pkgsOld.coreutils
            pkgsOld.findutils
            pkgsOld.gnugrep
            pkgsOld.gnused
            pkgsOld.git
            pkgsOld.curl
            pkgsOld.wget
            pkgsOld.gcc
            pkgsOld.gnumake
            pkgsOld.binutils
            pkgsOld.pkg-config
            pkgsOld.zlib
            pkgsOld.bzip2
            pkgsOld.openssl
            pkgsOld.libffi
            pkgsOld.ncurses
            pkgsOld.readline
            pkgsOld.stdenv.cc.cc.lib
            pkgsOld.gcc.cc.lib
            pkgsOld.icu
            pkgsOld.sqlite
          ];
          config = {
            Cmd = [ "${pkgsOld.python38}/bin/python3" ];
            WorkingDir = "/";
            Env = [
              "PATH=${stereopyEnv}/bin:${pkgsOld.lib.makeBinPath [ pkgsOld.bash pkgsOld.coreutils ]}"
              "PYTHONUNBUFFERED=1"
              "LD_LIBRARY_PATH=${pkgsOld.lib.makeLibraryPath [ pkgsOld.zlib pkgsOld.bzip2 pkgsOld.openssl pkgsOld.libffi pkgsOld.ncurses pkgsOld.stdenv.cc.cc.lib pkgsOld.gcc.cc.lib pkgsOld.icu pkgsOld.sqlite ]}"
            ];
          };
        };

        visiumhdZarrImage = pkgsStable.dockerTools.buildLayeredImage {
          name = "visiumhd-zarr";
          tag = "v0.0.1";
          contents = [
            visiumhdZarrEnv
            pkgsStable.python312
            pkgsStable.bash
            pkgsStable.coreutils
            pkgsStable.findutils
            pkgsStable.gnugrep
            pkgsStable.gnused
            pkgsStable.git
            pkgsStable.curl
            pkgsStable.wget
            pkgsStable.gcc
            pkgsStable.gnumake
            pkgsStable.binutils
            pkgsStable.pkg-config
            pkgsStable.zlib
            pkgsStable.bzip2
            pkgsStable.openssl
            pkgsStable.libffi
            pkgsStable.ncurses
            pkgsStable.readline
          ];
          config = {
            Cmd = [ "${pkgsStable.python312}/bin/python3" ];
            WorkingDir = "/";
            Env = [
              "PATH=${visiumhdZarrEnv}/bin:${pkgsStable.lib.makeBinPath [ pkgsStable.bash pkgsStable.coreutils ]}"
              "PYTHONUNBUFFERED=1"
              "LD_LIBRARY_PATH=${pkgsStable.lib.makeLibraryPath [ pkgsStable.zlib pkgsStable.bzip2 pkgsStable.openssl pkgsStable.libffi pkgsStable.ncurses ]}"
            ];
          };
        };

        # ==============================================================================
        # HELPER FUNCTIONS AND APPS
        # ==============================================================================

        copyImageToDir = name: targetDir: pkgs.writeShellApplication {
          name = "copy-${name}-image";
          runtimeInputs = [ pkgs.coreutils pkgs.nix ];
          text = ''
            TARGET_DIR="''${1:-${targetDir}}"
            
            mkdir -p "$TARGET_DIR"
            
            echo "Building ${name} image..."
            TEMP_RESULT=$(mktemp -d)
            nix build .#${name}-image --out-link "$TEMP_RESULT/result"
            
            if [ ! -e "$TEMP_RESULT/result" ]; then
              echo "Error: Failed to build ${name} image"
              exit 1
            fi
            
            IMAGE_FILE="${name}-v0.0.1.tar"
            cp "$TEMP_RESULT/result" "$TARGET_DIR/$IMAGE_FILE"
            
            rm -rf "$TEMP_RESULT"
            
            echo "Image copied to: $TARGET_DIR/$IMAGE_FILE"
            echo "Load into Docker with: docker load -i $TARGET_DIR/$IMAGE_FILE"
            echo "Load into Podman with: podman load -i $TARGET_DIR/$IMAGE_FILE"
          '';
        };

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.python312
            pkgs.uv
            pkgs.git
            pkgs.nextflow
          ];

          shellHook = ''
            export FLAKE_DIR="''${PWD}"
            
            echo "Installing SPIX dependencies with uv..."
            if [ -d "$FLAKE_DIR/uv-projects/spix" ]; then
              cd "$FLAKE_DIR/uv-projects/spix"
              uv sync --python ${pkgs.python312}/bin/python --active
              source .venv/bin/activate
              cd "$FLAKE_DIR"
            else
              echo "Warning: uv-projects/spix directory not found at $FLAKE_DIR/uv-projects/spix"
            fi
            
            echo "SPIX Analysis Shell Activated"
          '';
        };

        packages = {
          spix-image = spixImage;
          stereopy-image = stereopyImage;
          visiumhd-zarr-image = visiumhdZarrImage;
          spix-python = spixEnv;
          stereopy-python = stereopyEnv;
          visiumhd-zarr-python = visiumhdZarrEnv;
        };

        apps = {
          copy-spix-image = {
            type = "app";
            program = "${copyImageToDir "spix" "./container_cache"}/bin/copy-spix-image";
          };
          copy-stereopy-image = {
            type = "app";
            program = "${copyImageToDir "stereopy" "./container_cache"}/bin/copy-stereopy-image";
          };
          copy-visiumhd-zarr-image = {
            type = "app";
            program = "${copyImageToDir "visiumhd-zarr" "./container_cache"}/bin/copy-visiumhd-zarr-image";
          };
        };

        defaultPackage = spixImage;
      }
    );
}