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

            __noChroot = true;
            phases = [ "unpackPhase" "buildPhase" "installPhase" ];

            buildPhase = ''
              export HOME=$(mktemp -d)
              export UV_NO_CACHE=1
              cd uv-projects/${projectName}
              ${pythonPkgs}/bin/python -m venv $HOME/.venv
              export PATH="$HOME/.venv/bin:$PATH"
              ${nixpkgs.uv}/bin/uv venv $HOME/.venv --python ${pythonPkgs}/bin/python
              ${nixpkgs.uv}/bin/uv sync --python ${pythonPkgs}/bin/python
              cd - > /dev/null
            '';

            installPhase = ''
              mkdir -p $out
              cp -r $HOME/.venv/* $out/
            '';
          };

        # Helper function to create a Python environment using pip (for legacy packages)
        mkPipPythonEnv = { pythonPkgs, projectName, requirementsFile ? "requirements.txt", nixpkgs ? pkgs }:
          nixpkgs.stdenv.mkDerivation {
            name = "${projectName}-env";
            src = ./.;

            buildInputs = [
              pythonPkgs
              nixpkgs.pip
            ];

            phases = [ "unpackPhase" "buildPhase" "installPhase" ];

            buildPhase = ''
              export HOME=$(mktemp -d)
              cd uv-projects/${projectName}
              ${pythonPkgs}/bin/python -m venv $HOME/.venv
              export PATH="$HOME/.venv/bin:$PATH"
              if [ -f "${requirementsFile}" ]; then
                pip install -r ${requirementsFile}
              else
                pip install -e .
              fi
              cd - > /dev/null
            '';

            installPhase = ''
              mkdir -p $out
              cp -r $HOME/.venv/* $out/
            '';
          };

        # Helper function to create a conda-based Python environment
        mkCondaPythonEnv = { pythonVersion, projectName, condaPackages, nixpkgs ? pkgs }:
          nixpkgs.stdenv.mkDerivation {
            name = "${projectName}-env";
            src = ./.;

            buildInputs = [
              nixpkgs.miniconda3
              nixpkgs.bash
            ];

            phases = [ "unpackPhase" "buildPhase" "installPhase" ];

            buildPhase = ''
              export HOME=$(mktemp -d)
              export PATH="${nixpkgs.miniconda3}/bin:$PATH"
              
              # Initialize conda
              eval "$(${nixpkgs.miniconda3}/bin/conda shell.bash hook)"
              
              # Create conda environment
              conda create -y -p $HOME/conda-env -c conda-forge \
                python=${pythonVersion} \
                ${nixpkgs.lib.concatStringsSep " \\\n  " condaPackages}
              
              # Activate and install stereopy
              conda activate $HOME/conda-env
              pip install stereopy
            '';

            installPhase = ''
              mkdir -p $out
              cp -r $HOME/conda-env/* $out/
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

        stereopyEnv = mkCondaPythonEnv {
          pythonVersion = "3.8";
          projectName = "stereopy";
          condaPackages = [
            "ipython"
            "libstdcxx-ng"
            "libgcc-ng"
            "icu"
            "sqlite"
            "anndata"
            "scanpy"
          ];
          nixpkgs = pkgsStable;
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

        stereopyImage = pkgsStable.dockerTools.buildLayeredImage {
          name = "stereopy";
          tag = "v0.0.1";
          contents = [
            stereopyEnv
            pkgsStable.bash
            pkgsStable.coreutils
            pkgsStable.findutils
            pkgsStable.gnugrep
            pkgsStable.gnused
            pkgsStable.git
            pkgsStable.curl
            pkgsStable.wget
          ];
          config = {
            Cmd = [ "${stereopyEnv}/bin/python3" ];
            WorkingDir = "/";
            Env = [
              "PATH=${stereopyEnv}/bin:${pkgsStable.lib.makeBinPath [ pkgsStable.bash pkgsStable.coreutils ]}"
              "PYTHONUNBUFFERED=1"
              "LD_LIBRARY_PATH=${stereopyEnv}/lib:''${LD_LIBRARY_PATH:-}"
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

        devShells.stereopy = pkgsStable.mkShell {
          buildInputs = [
            pkgsStable.miniconda3
            pkgsStable.git
          ];

          shellHook = ''
            export FLAKE_DIR="''${PWD}"
            
            echo "Setting up stereopy environment with conda..."
            eval "$(${pkgsStable.miniconda3}/bin/conda shell.bash hook)"
            
            if ! conda env list | grep -q stereo_stable; then
              conda create -y -n stereo_stable -c conda-forge \
                python=3.8 \
                ipython \
                libstdcxx-ng \
                libgcc-ng \
                icu \
                sqlite
              
              conda activate stereo_stable
              pip install stereopy
            else
              conda activate stereo_stable
            fi
            
            export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:''${LD_LIBRARY_PATH:-}"
            
            echo "Stereopy Shell Activated (Python 3.8 with Conda)"
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