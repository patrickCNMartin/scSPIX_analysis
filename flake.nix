{
  description = "SPIX Analysis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.python3
            python312Packages.pyyaml
            pkgs.git
            pkgs.nextflow
          ];

          shellHook = ''
            echo "SPIX Analysis Shell Activated"

           '';
        };
      }
    );
}