{
  description = "SPIX Analysis - Focused UV Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # The GitHub source for the SPIX code
    spix-src.url = "github:whistle-ch0i/SPIX";
    spix-src.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, spix-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # This builds the python environment using the local uv files
        spixEnv = pkgs.stdenv.mkDerivation {
          name = "spix-env";
          src = ./.;

          buildInputs = [
            pkgs.python312
            pkgs.uv
          ];

          __noChroot = true;
          
          phases = [ "unpackPhase" "buildPhase" "installPhase" ];

          buildPhase = ''
            export HOME=$(mktemp -d)
            export UV_NO_CACHE=1
            
            cd container_def/spix
            
            echo "Building SPIX environment from local uv config..."
            ${pkgs.uv}/bin/uv venv $HOME/.venv --python ${pkgs.python312}/bin/python
            ${pkgs.uv}/bin/uv sync --python ${pkgs.python312}/bin/python
            
            cd - > /dev/null
          '';

          installPhase = ''
            mkdir -p $out
            cp -r $HOME/.venv/* $out/
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

          # We make the github source available as an environment variable
          shellHook = ''
            export FLAKE_DIR="''${PWD}"
            export SPIX_PROJECT_DIR="$FLAKE_DIR/container_def/spix"
            export SPIX_SOURCE="${spix-src}"
            
            echo "--- SPIX Analysis Shell ---"
            echo "External SPIX Source: $SPIX_SOURCE"
            
            if [ -d "$SPIX_PROJECT_DIR" ]; then
              cd "$SPIX_PROJECT_DIR"
              echo "Syncing local uv environment..."
              uv sync --python ${pkgs.python312}/bin/python
              source .venv/bin/activate
              cd "$FLAKE_DIR"
              
              echo "----------------------------------------------------"
              echo "Environment Ready (Python 3.12)"
              echo "To access SPIX source code, use: cd \$SPIX_SOURCE"
              echo "----------------------------------------------------"
            else
              echo "Error: Directory $SPIX_PROJECT_DIR not found."
              echo "Please ensure container_def/spix/ exists in your project root."
            fi
          '';
        };

        packages.spix-python = spixEnv;
        defaultPackage = spixEnv;
      }
    );
}