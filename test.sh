#!/usr/bin/env bash

# Make sure we can extract ASTs for the top 10 Hackage packages

ERR=0
REL=$(dirname "$0")
SOURCE=$(readlink -f "$REL")

echo "Using '$SOURCE/default.nix'"

function pkgs {
    echo "list-extras"
    return 0
    cat <<EOF
text
vector
aeson
Cabal
attoparsec
pandoc
lens
http-conduit
http-client
EOF
}

function testPkg {

read -r -d '' ENV <<EOF
with import <nixpkgs> {};

runCommand "dummy" {
  buildInputs = [
    haskellPackages.cabal-install
    (haskellPackages.ghcWithPackages (hsPkgs: [
      hsPkgs.$1
      (hsPkgs.callPackage (import $SOURCE/default.nix) {})
    ]))
  ];
} ""
EOF

read -r -d '' CMD <<'EOF'
set -x
GHC_PKG=$(ghc-pkg list | head -n 1 | tr -d ':')
OPTIONS="-package-db=$GHC_PKG -package AstPlugin -fplugin=AstPlugin.Plugin"
cabal update    &&
cabal configure &&
cabal --ghc-options="$OPTIONS" -v build \
    1> >(tee stdout | grep -v '^{')     \
    2> >(tee stderr | grep -v '^{')
EOF

  nix-shell -E "$ENV" --run "$CMD" || ERR=1
  cat stdout stderr | grep "^{" > /dev/null || {
      echo "No ASTs found for $1"
      ERR=1
  }
}

while read -r PKG
do
    DIR=$(mktemp -d "/tmp/astplugin-testXXXXXX")
    cd "$DIR"
    nix-shell -p haskellPackages.cabal-install --run "cabal get $PKG" || ERR=1
    for SUBDIR in ./*
    do
        cd "$SUBDIR"
        testPkg "$PKG"
    done
    cd /tmp
    rm -rf "$DIR"
done < <(pkgs)

[[ "$ERR" -eq 0 ]] || echo "Errors were encountered" >> /dev/stderr
exit "$ERR"
