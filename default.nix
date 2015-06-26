{ mkDerivation, base, ghc, stdenv }:
mkDerivation {
  pname = "AstPlugin";
  version = "0.1.0.0";
  src = ./.;
  buildDepends = [ base ghc ];
  homepage = "http://chriswarbo.net/git/ast-plugin";
  description = "GHC plugin to spit out ASTs";
  license = stdenv.lib.licenses.publicDomain;
}
