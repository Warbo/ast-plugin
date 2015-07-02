{ mkDerivation, base, ghc, HS2AST, QuickCheck, stdenv, tasty
, tasty-quickcheck
}:
mkDerivation {
  pname = "AstPlugin";
  version = "0.1.0.0";
  src = ./.;
  buildDepends = [ base ghc HS2AST ];
  testDepends = [ base HS2AST QuickCheck tasty tasty-quickcheck ];
  homepage = "http://chriswarbo.net/git/ast-plugin";
  description = "GHC plugin to spit out ASTs";
  license = stdenv.lib.licenses.publicDomain;
}
