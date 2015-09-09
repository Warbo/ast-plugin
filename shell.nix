{ nixpkgs ? import <nixpkgs> {}, compiler ? "default" }:

let

  inherit (nixpkgs) pkgs;

  f = { mkDerivation, aeson, base, ghc, HS2AST, QuickCheck, stdenv
      , stringable, tasty, tasty-quickcheck
      }:
      mkDerivation {
        pname = "AstPlugin";
        version = "0.1.0.0";
        src = ./.;
        libraryHaskellDepends = [ aeson base ghc HS2AST stringable ];
        testHaskellDepends = [
          aeson base HS2AST QuickCheck stringable tasty tasty-quickcheck
        ];
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
