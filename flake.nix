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

        # Helper function to create Python environment using uv with pyproject.toml
        mkUvEnv = pythonPkgs: projectDir:
          pkgs.runCommand "uv-env" {
            buildInputs = [ pythonPkgs pkgs.uv ];
            __noChroot = true;  # Allow network access for uv
          } ''
            export HOME=$TMPDIR
            mkdir -p $out/lib/${pythonPkgs.libPrefix}/site-packages

            # Copy the uv project
            cp -r ${projectDir} $TMPDIR/project
            cd $TMPDIR/project

            # Use uv to sync dependencies (excluding the project itself)
            uv sync --no-install-project --python ${pythonPkgs}/bin/python

            # Copy the virtual environment to output
            if [ -d .venv/lib/${pythonPkgs.libPrefix}/site-packages ]; then
              cp -r .venv/lib/${pythonPkgs.libPrefix}/site-packages/* $out/lib/${pythonPkgs.libPrefix}/site-packages/
            fi

            mkdir -p $out/bin
            cp ${pythonPkgs}/bin/* $out/bin/
          '';

        # SPIX environment using uv + SPIX from git
        spixUvEnv = mkUvEnv pkgs.python312 ./uv-projects/spix;
        spixEnv = pkgs.runCommand "spix-env" {
          buildInputs = [ spixUvEnv pkgs.python312 ];
        } ''
          export PYTHONPATH="${spixUvEnv}/lib/${pkgs.python312.libPrefix}/site-packages:$PYTHONPATH"
          export PATH="${spixUvEnv}/bin:$PATH"
          export HOME=$TMPDIR

          mkdir -p $out/lib/${pkgs.python312.libPrefix}/site-packages
          cp -r ${spixUvEnv}/lib/${pkgs.python312.libPrefix}/site-packages/* $out/lib/${pkgs.python312.libPrefix}/site-packages/

          # Install SPIX from git (uv handles most deps, we add SPIX separately)
          cp -r ${spix} $TMPDIR/spix-src
          chmod -R +w $TMPDIR/spix-src
          pip install --target $out/lib/${pkgs.python312.libPrefix}/site-packages --no-deps --no-build-isolation $TMPDIR/spix-src

          mkdir -p $out/bin
          cp ${spixUvEnv}/bin/* $out/bin/
        '';

        spixUvEnvStable = mkUvEnv pkgsStable.python312 ./uv-projects/spix;
        spixEnvStable = pkgsStable.runCommand "spix-env-stable" {
          buildInputs = [ spixUvEnvStable pkgsStable.python312 ];
        } ''
          export PYTHONPATH="${spixUvEnvStable}/lib/${pkgsStable.python312.libPrefix}/site-packages:$PYTHONPATH"
          export PATH="${spixUvEnvStable}/bin:$PATH"
          export HOME=$TMPDIR

          mkdir -p $out/lib/${pkgsStable.python312.libPrefix}/site-packages
          cp -r ${spixUvEnvStable}/lib/${pkgsStable.python312.libPrefix}/site-packages/* $out/lib/${pkgsStable.python312.libPrefix}/site-packages/

          # Install SPIX from git (uv handles most deps, we add SPIX separately)
          cp -r ${spix} $TMPDIR/spix-src
          chmod -R +w $TMPDIR/spix-src
          pip install --target $out/lib/${pkgsStable.python312.libPrefix}/site-packages --no-deps --no-build-isolation $TMPDIR/spix-src

          mkdir -p $out/bin
          cp ${spixUvEnvStable}/bin/* $out/bin/
        '';

        # Stereopy environment using uv
        stereopyPythonWithPip = mkUvEnv pkgsOld.python38 ./uv-projects/stereopy;

        # VisiumHD Zarr environment using uv
        visiumhdZarrPythonWithPip = mkUvEnv pkgsStable.python312 ./uv-projects/visiumhd-zarr;

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