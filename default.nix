{ mkDerivation, aeson, base, ghc, HS2AST, QuickCheck, stdenv
, stringable, tasty, tasty-quickcheck
}:
mkDerivation {
  pname = "AstPlugin";
  version = "0.1.0.0";
  src = ./.;
  buildDepends = [ aeson base ghc HS2AST stringable ];
  testDepends = [
    aeson base HS2AST QuickCheck stringable tasty tasty-quickcheck
  ];
  homepage = "http://chriswarbo.net/git/ast-plugin";
  description = "GHC plugin to spit out ASTs";
  license = stdenv.lib.licenses.publicDomain;
}
