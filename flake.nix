{
  description = "SPIX Analysis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-22-11.url = "github:NixOS/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
    spix.url = "github:whistle-ch0i/SPIX";
    spix.flake = false;
    ux2nix.url = "github:adisbladis/ux2nix";
    ux2nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-22-11, flake-utils, spix, ux2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgsStable = import nixpkgs-stable { inherit system; };
        pkgsOld = import nixpkgs-22-11 { inherit system; };

        # SPIX environment using ux2nix
        spixEnvInputs = ux2nix.lib.mkEnvs {
          python = pkgs.python312;
          src = ./uv-projects/spix;
        };

        # SPIX environments using ux2nix
        spixEnv = spixEnvInputs.default;
        spixEnvStable = (ux2nix.lib.mkEnvs {
          python = pkgsStable.python312;
          src = ./uv-projects/spix;
        }).default;

        # Stereopy environment using ux2nix
        stereopyPythonWithPip = (ux2nix.lib.mkEnvs {
          python = pkgsOld.python38;
          src = ./uv-projects/stereopy;
        }).default;

        # VisiumHD Zarr environment using ux2nix
        visiumhdZarrPythonWithPip = (ux2nix.lib.mkEnvs {
          python = pkgsStable.python312;
          src = ./uv-projects/visiumhd-zarr;
        }).default;

        # ==============================================================================
        # OCI IMAGES
        # ==============================================================================

        spixImage = pkgsStable.dockerTools.buildLayeredImage {
          name = "spix";
          tag = "v0.0.1";
          contents = [
            spixEnvStable
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
            Cmd = [ "${spixEnvStable}/bin/python3" ];
            WorkingDir = "/";
            Env = [
              "PATH=${pkgsStable.lib.makeBinPath [ spixEnvStable pkgsStable.bash pkgsStable.coreutils ]}"
              "PYTHONPATH=${spixEnvStable}/lib/${pkgsStable.python312.libPrefix}/site-packages:$PYTHONPATH"
              "PYTHONUNBUFFERED=1"
              "LD_LIBRARY_PATH=${pkgsStable.lib.makeLibraryPath [ spixEnvStable pkgsStable.zlib pkgsStable.bzip2 pkgsStable.openssl pkgsStable.libffi pkgsStable.ncurses ]}"
            ];
          };
        };

        stereopyImage = pkgsOld.dockerTools.buildLayeredImage {
          name = "stereopy";
          tag = "v0.0.1";
          contents = [
            stereopyPythonWithPip
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
            Cmd = [ "${stereopyPythonWithPip}/bin/python3" ];
            WorkingDir = "/";
            Env = [
              "PATH=${pkgsOld.lib.makeBinPath [ stereopyPythonWithPip pkgsOld.bash pkgsOld.coreutils ]}"
              "PYTHONUNBUFFERED=1"
              "LD_LIBRARY_PATH=${pkgsOld.lib.makeLibraryPath [ pkgsOld.zlib pkgsOld.bzip2 pkgsOld.openssl pkgsOld.libffi pkgsOld.ncurses pkgsOld.stdenv.cc.cc.lib pkgsOld.gcc.cc.lib pkgsOld.icu pkgsOld.sqlite ]}"
            ];
          };
        };

        visiumhdZarrImage = pkgsStable.dockerTools.buildLayeredImage {
          name = "visiumhd-zarr";
          tag = "v0.0.1";
          contents = [
            visiumhdZarrPythonWithPip
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
            Cmd = [ "${visiumhdZarrPythonWithPip}/bin/python3" ];
            WorkingDir = "/";
            Env = [
              "PATH=${pkgsStable.lib.makeBinPath [ visiumhdZarrPythonWithPip pkgsStable.bash pkgsStable.coreutils ]}"
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
            spixEnv
            pkgs.git
            pkgs.nextflow
          ];

          shellHook = ''
            export PYTHONPATH="${spixEnv}/lib/${pkgs.python312.libPrefix}/site-packages:$PYTHONPATH"
            export PATH="${spixEnv}/bin:$PATH"
            echo "SPIX Analysis Shell Activated"
            echo "SPIX package available: $(python3 -c 'import SPIX; print(SPIX.__file__)' 2>/dev/null || echo 'Not found')"
          '';
        };

        packages = {
          spix-image = spixImage;
          stereopy-image = stereopyImage;
          visiumhd-zarr-image = visiumhdZarrImage;
          spix-python = spixEnv;
          stereopy-python = stereopyPythonWithPip;
          visiumhd-zarr-python = visiumhdZarrPythonWithPip;
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