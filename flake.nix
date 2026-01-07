{
  description = "SPIX Analysis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # For dev shell
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05"; # For OCI images (spix, visiumhd-zarr)
    nixpkgs-22-11.url = "github:NixOS/nixpkgs/nixos-22.11"; # For stereopy OCI image (python38)
    flake-utils.url = "github:numtide/flake-utils";
    spix.url = "github:whistle-ch0i/SPIX";
    spix.flake = false;
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nixpkgs-22-11, flake-utils, spix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Unstable nixpkgs for dev shell
        pkgs = import nixpkgs { inherit system; };
        # Stable nixpkgs for OCI images
        pkgsStable = import nixpkgs-stable { inherit system; };
        # Older nixpkgs (22.11) for stereopy (requires python38)
        pkgsOld = import nixpkgs-22-11 { inherit system; };

        # SPIX package built from GitHub source
        spixPackage = pkgs.python312Packages.buildPythonPackage {
          pname = "SPIX";
          version = "0.1.0";
          src = spix;
          format = "pyproject";

          # Build dependencies - setuptools and wheel are required by SPIX's pyproject.toml
          nativeBuildInputs = with pkgs.python312Packages; [
            setuptools
            wheel
          ];

          # Runtime dependencies from SPIX pyproject.toml
          propagatedBuildInputs = with pkgs.python312Packages; [
            numpy
            scipy
            matplotlib
            pandas
            scikit-learn
            requests
            seaborn
            scikit-image
            anndata
            joblib
            # opencv4 - let opencv-python from pip take precedence
            networkx
            shapely
            tqdm
            minisom  # Available in nixpkgs
            python-igraph  # Available in nixpkgs (igraph package)
            # Note: scanpy removed due to platform compatibility issues (tuna dependency)
            # Note: Some dependencies like squidpy, alphashape, harmonypy,
            # NaiveDE, tqdm_joblib are in pip requirements
          ];

          # SPIX might have additional dependencies that need to be installed
          # Let's try to build it and see what happens
          doCheck = false; # Skip tests for now
        };

        # SPIX Python environment - packages from spix_1007.yml
        # Using Python 3.12 to match Dockerfile base image
        spixPythonBase = pkgs.python312.withPackages (ps: with ps; [
          # Core Python packages (from conda dependencies in yml)
          pip
          setuptools
          wheel

          # Scientific computing packages available in nixpkgs
          numpy
          scipy
          pandas
          matplotlib
          seaborn
          scikit-learn
          scikit-image
          h5py
          pillow
          pyyaml
          requests
          tqdm
          joblib
          networkx
          patsy
          statsmodels

          # Bioinformatics/spatial analysis packages
          anndata
          # scanpy - installed via pip due to platform compatibility issues
          # celltypist - may need pip
          # squidpy - may need pip
          # spatialdata - may need pip
          # spatialdata-io - may need pip
          geopandas
          shapely
          pyproj
          rtree

          # Image processing
          imageio
          # imagecodecs - may need pip
          # tifffile - may need pip
          # opencv4 - let opencv-python from pip take precedence

          # Data handling
          zarr
          numcodecs
          fsspec
          # s3fs - may need pip
          pyarrow
          xarray
          dask

          # Visualization
          # datashader - may need pip
          # colorcet - may need pip
          # holoviews - may need pip
          # param - may need pip

          # Jupyter/IPython
          ipython
          ipykernel
          jupyter
          notebook

          # Other utilities
          click
          pygments
          packaging
          typing-extensions
          pydantic

          # Additional common packages
          attrs
          certifi
          charset-normalizer
          idna
          urllib3
          cloudpickle
          decorator
          exceptiongroup
          importlib-metadata
          more-itertools
          six
        ]);

        # SPIX Python environment with SPIX package added
        spixPython = spixPythonBase.withPackages (ps: [ spixPackage ]);
        
        # SPIX pip requirements (packages not available in nixpkgs)
        spixPipRequirements = pkgs.writeText "spix-requirements.txt" ''
          aiobotocore==2.24.2
          aiohappyeyeballs==2.6.1
          aiohttp==3.13.0
          aioitertools==0.12.0
          aiosignal==1.4.0
          alphashape==1.3.1
          anndata==0.11.4
          annotated-types==0.7.0
          array-api-compat==1.12.0
          asciitree==0.3.3
          asttokens==3.0.0
          async-timeout==5.0.1
          botocore==1.40.18
          celltypist==1.7.1
          click-log==0.4.0
          colorcet==3.1.0
          comm==0.2.3
          contourpy==1.3.2
          cycler==0.12.1
          dask-expr==1.1.19
          dask-image==2024.5.3
          datashader==0.18.2
          debugpy==1.8.17
          docrep==0.3.2
          et-xmlfile==2.0.0
          executing==2.2.1
          fasteners==0.20
          flowio==1.4.0
          fonttools==4.60.1
          frozenlist==1.8.0
          harmonypy==0.0.10
          igraph==0.11.9
          imagecodecs==2025.3.30
          inflect==7.5.0
          jmespath==1.0.1
          jupyter-client==8.6.3
          jupyter-core==5.8.1
          kiwisolver==1.4.9
          lazy-loader==0.4
          legacy-api-wrap==1.4.1
          leidenalg==0.10.2
          llvmlite==0.45.1
          locket==1.0.0
          markdown-it-py==4.0.0
          matplotlib-inline==0.1.7
          matplotlib-scalebar==0.9.0
          mdurl==0.1.2
          minisom==2.3.5
          multidict==6.7.0
          multipledispatch==1.0.0
          multiscale-spatial-image==2.0.3
          naivede==1.2.0
          natsort==8.4.0
          nest-asyncio==1.6.0
          numba==0.62.1
          ome-types==0.6.1
          ome-zarr==0.11.1
          omnipath==1.0.12
          opencv-python==4.12.0.88
          openpyxl==3.1.5
          param==2.2.1
          parso==0.8.5
          partd==1.4.2
          pexpect==4.9.0
          pims==0.7
          platformdirs==4.4.0
          pooch==1.8.2
          prompt-toolkit==3.0.52
          propcache==0.4.0
          psutil==7.1.0
          ptyprocess==0.7.0
          pure-eval==0.2.3
          pydantic-core==2.41.1
          pydantic-extra-types==2.10.5
          pynndescent==0.5.13
          pyogrio==0.11.1
          pyparsing==3.2.5
          python-dateutil==2.9.0.post0
          pytz==2025.2
          pyzmq==27.1.0
          readfcs==2.0.1
          rich==14.1.0
          s3fs==2025.9.0
          scanpy==1.11.4
          session-info2==0.2.2
          slicerator==1.1.0
          spatial-image==1.2.3
          spatialdata==0.5.0
          spatialdata-io==0.3.0
          squidpy==1.6.5
          stack-data==0.6.3
          texttable==1.7.0
          threadpoolctl==3.6.0
          tifffile==2025.5.10
          toolz==1.0.0
          tornado==6.5.2
          tqdm-joblib==0.0.5
          traitlets==5.14.3
          trimesh==4.8.3
          typeguard==4.4.4
          typing-inspection==0.4.2
          umap-learn==0.5.9.post2
          validators==0.35.0
          wcwidth==0.2.14
          wrapt==1.17.3
          xarray-dataclass==3.0.0
          xarray-schema==0.0.3
          xarray-spatial==0.4.0
          xsdata==24.3.1
          yarl==1.22.0
          papermill
          zipp==3.23.0
        '';
        
        # SPIX Python environment with pip packages pre-installed
        spixPythonWithPip = pkgs.runCommand "spix-python-with-pip" {
          buildInputs = [ spixPython ];
        } ''
          mkdir -p $out
          # Copy Python environment
          cp -r ${spixPython}/* $out/
          chmod -R +w $out
          
          # Install pip packages into the Python environment
          export HOME=$TMPDIR
          ${spixPython}/bin/pip install --prefix $out -r ${spixPipRequirements}
        '';
        
        # Note that stereopy requires python3.8 - outdated
        stereopyPython = pkgsOld.python38.withPackages (ps: with ps; [
          pip
          setuptools
          ipython  # From conda requirement
        ]);
        
        # Stereopy pip requirements
        stereopyPipRequirements = pkgs.writeText "stereopy-requirements.txt" ''
          stereopy
          anndata==0.11.4
          scanpy==1.11.4
        '';
        
        # Stereopy Python environment with pip packages pre-installed
        stereopyPythonWithPip = pkgsOld.runCommand "stereopy-python-with-pip" {
          buildInputs = [ stereopyPython ];
        } ''
          mkdir -p $out
          cp -r ${stereopyPython}/* $out/
          chmod -R +w $out
          
          export HOME=$TMPDIR
          ${stereopyPython}/bin/pip install --prefix $out -r ${stereopyPipRequirements}
        '';
        
        # VisiumHD Zarr Python environment
        visiumhdZarrPython = pkgs.python312.withPackages (ps: with ps; [
          pip
          setuptools
        ]);
        
        # VisiumHD Zarr pip requirements
        visiumhdZarrPipRequirements = pkgs.writeText "visiumhd-zarr-requirements.txt" ''
          spatialdata-io
        '';
        
        # VisiumHD Zarr Python environment with pip packages pre-installed
        visiumhdZarrPythonWithPip = pkgs.runCommand "visiumhd-zarr-python-with-pip" {
          buildInputs = [ visiumhdZarrPython ];
        } ''
          mkdir -p $out
          cp -r ${visiumhdZarrPython}/* $out/
          chmod -R +w $out
          
          export HOME=$TMPDIR
          ${visiumhdZarrPython}/bin/pip install --prefix $out -r ${visiumhdZarrPipRequirements}
        '';

        # ==============================================================================
        # OCI IMAGES
        # ==============================================================================

        # SPIX OCI Image - using Python environment with pip packages pre-installed
        spixImage = pkgsStable.dockerTools.buildLayeredImage {
          name = "spix";
          tag = "v0.0.1";
          contents = [
            spixPythonWithPip
            pkgsStable.bash
            pkgsStable.coreutils
            pkgsStable.findutils
            pkgsStable.gnugrep
            pkgsStable.gnused
            pkgsStable.git
            pkgsStable.curl
            pkgsStable.wget
            # Build tools (needed for some Python packages)
            pkgsStable.gcc
            pkgsStable.gnumake
            pkgsStable.binutils
            pkgsStable.pkg-config
            # System libraries
            pkgsStable.zlib
            pkgsStable.bzip2
            pkgsStable.openssl
            pkgsStable.libffi
            pkgsStable.ncurses
            pkgsStable.readline
          ];
          config = {
            Cmd = [ "${spixPythonWithPip}/bin/python3" ];
            WorkingDir = "/";
            Env = [
              "PATH=${pkgsStable.lib.makeBinPath [ spixPythonWithPip pkgsStable.bash pkgsStable.coreutils ]}"
              "PYTHONUNBUFFERED=1"
              "LD_LIBRARY_PATH=${pkgsStable.lib.makeLibraryPath [ pkgsStable.zlib pkgsStable.bzip2 pkgsStable.openssl pkgsStable.libffi pkgsStable.ncurses ]}"
            ];
          };
        };
        
        # Stereopy OCI Image
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
            # Build tools
            pkgsOld.gcc
            pkgsOld.gnumake
            pkgsOld.binutils
            pkgsOld.pkg-config
            # System libraries (matching conda environment)
            pkgsOld.zlib
            pkgsOld.bzip2
            pkgsOld.openssl
            pkgsOld.libffi
            pkgsOld.ncurses
            pkgsOld.readline
            # Additional conda packages: libstdcxx-ng, libgcc-ng, icu, sqlite
            pkgsOld.stdenv.cc.cc.lib  # libstdcxx-ng
            pkgsOld.gcc.cc.lib        # libgcc-ng
            pkgsOld.icu                # icu
            pkgsOld.sqlite             # sqlite
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
        
        # VisiumHD Zarr OCI Image
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
            # Build tools
            pkgsStable.gcc
            pkgsStable.gnumake
            pkgsStable.binutils
            pkgsStable.pkg-config
            # System libraries
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

        # Helper function to create a script that copies image to target directory
        copyImageToDir = name: targetDir: pkgs.writeShellApplication {
          name = "copy-${name}-image";
          runtimeInputs = [ pkgs.coreutils pkgs.nix ];
          text = ''
            # Default target directory if not specified
            TARGET_DIR="''${1:-${targetDir}}"
            
            # Create target directory if it doesn't exist
            mkdir -p "$TARGET_DIR"
            
            # Build the image
            echo "Building ${name} image..."
            TEMP_RESULT=$(mktemp -d)
            nix build .#${name}-image --out-link "$TEMP_RESULT/result"
            
            if [ ! -e "$TEMP_RESULT/result" ]; then
              echo "Error: Failed to build ${name} image"
              exit 1
            fi
            
            # Copy image to target directory
            IMAGE_FILE="${name}-v0.0.1.tar"
            cp "$TEMP_RESULT/result" "$TARGET_DIR/$IMAGE_FILE"
            
            # Clean up temp directory
            rm -rf "$TEMP_RESULT"
            
            echo "Image copied to: $TARGET_DIR/$IMAGE_FILE"
            echo "Load into Docker with: docker load -i $TARGET_DIR/$IMAGE_FILE"
            echo "Load into Podman with: podman load -i $TARGET_DIR/$IMAGE_FILE"
          '';
        };

        # ==============================================================================
        # FLAKE OUTPUTS
        # ==============================================================================

      in {
        # Development shell (uses unstable nixpkgs)
        devShells.default = pkgs.mkShell {
          buildInputs = [
            spixPackage
            spixPython
            pkgs.git
            pkgs.nextflow
          ];

          shellHook = ''
            echo "SPIX Analysis Shell Activated"
            echo "SPIX package available: $(python3 -c 'import SPIX; print(SPIX.__file__)' 2>/dev/null || echo 'Not found')"
          '';
        };
        
        # OCI Images
        packages = {
          spix-image = spixImage;
          stereopy-image = stereopyImage;
          visiumhd-zarr-image = visiumhdZarrImage;
          
          # Also expose Python environments for direct use (with pip packages)
          spix-python = spixPythonWithPip;
          stereopy-python = stereopyPythonWithPip;
          visiumhd-zarr-python = visiumhdZarrPythonWithPip;
        };
        
        # Apps to copy images to a target directory
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
        
        # Default package
        defaultPackage = spixImage;
      }
    );
}
