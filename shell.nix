{ nixpkgs ? import <nixpkgs> {}, compiler ? "default" }:

let

  inherit (nixpkgs) pkgs;

  f = { mkDerivation, aeson, base, ghc, HS2AST, stdenv, stringable
      }:
      mkDerivation {
        pname = "AstPlugin";
        version = "0.1.0.0";
        src = ./.;
        libraryHaskellDepends = [ aeson base ghc HS2AST stringable ];
        homepage = "http://chriswarbo.net/git/ast-plugin";
        description = "GHC plugin to spit out ASTs";
        license = stdenv.lib.licenses.publicDomain;
      };

  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  drv = haskellPackages.callPackage f {};

in

  if pkgs.lib.inNixShell then drv.env else drv
