{
  mkShellNoCC,

  # extra tooling
  eslint_d,
  prettierd,
  typescript,

  callPackage,
}:
let
  defaultPackage = callPackage ./package.nix { };
in
mkShellNoCC {
  inputsFrom = [ defaultPackage ];

  packages = [
    eslint_d
    prettierd
    typescript
  ];
}
