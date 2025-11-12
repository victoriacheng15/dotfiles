{
  description = "Dev environment with Go, Node.js, and npm";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = [
          pkgs.go
          pkgs.nodejs
          pkgs.npm
          pkgs.python312Full
        ];
        shellHook = ''
          echo "Dev environment ready 🧰"
          echo "Go: $(go version | head -n 1)"
          echo "Node.js: $(node --version)"
          echo "npm: $(npm --version)"
          echo "Python: $(python3 --version)"
        '';
      };
    };
}
