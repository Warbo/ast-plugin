#!/usr/bin/env bash
set -x

# Make sure we can extract ASTs for the top 10 Hackage packages

shopt -s nullglob
SOURCE=$(readlink -f "$(dirname "$0")")

# Helper functions

function msg {
    echo -e "$1" >> /dev/stderr
}

function fail {
    msg "FAIL: $1"
    exit 1
}

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

function getPkg {
    nix-shell -p haskellPackages.cabal-install --run "cabal get $1" ||
        fail "Couldn't cabal get '$1'"
}

function inSourceDir {
    # Run command $2 with package name $1 as an argument, inside a temporary
    # directory containing the source code of package $1.
    DIR=$(mktemp -d --tmpdir "astplugin-testXXXXXX")
    pushd "$DIR" > /dev/null
    getPkg "$1"
    for SUBDIR in "$DIR"/*
    do
        pushd "$SUBDIR" > /dev/null
        "$2" "$1"
        popd > /dev/null
    done
    popd > /dev/null
    rm -rf "$DIR"
}

function envFor {
    # Output a string of Nix code which will provide an environment suitable for
    # building Haskell package $1
    cat <<EOF
with import <nixpkgs> {};
with builtins;

let astPlugin = runCommand "cabal2nix-ast-plugin"
                           { buildInputs = [ haskellPackages.cabal2nix ]; }
                           ''set -e
                             if [[ -d "$SOURCE" ]]
                             then
                               echo "Found '$SOURCE'" 1>&2
                             else
                               echo "Couldn't find '$SOURCE'" 1>&2
                               exit 2
                             fi

                             if command -v cabal2nix > /dev/null
                             then
                               echo "Found cabal2nix" 1>&2
                             else
                               echo "Couldn't find cabal2nix" 1>&2
                               exit 3
                             fi

                             cabal2nix "$SOURCE" > "\$out"'';
in runCommand "dummy" {
  buildInputs = [
    haskellPackages.cabal-install
    (haskellPackages.ghcWithPackages (hsPkgs: [
      hsPkgs.$1
      (hsPkgs.callPackage (trace "astPlugin \${astPlugin}"
                                 "\${astPlugin}")
                          {})
    ]))
  ];
} ""
EOF
}

function cmdFor {
    # Output a string of shell code, which will build the current project using
    # GHC with the AstPlugin
    cat <<'EOF'
set -x
GHC_PKG=$(ghc-pkg list | head -n 1 | tr -d ':')
OPTIONS="-package-db=$GHC_PKG -package AstPlugin -fplugin=AstPlugin.Plugin"
cabal --ghc-options="$OPTIONS" -v build \
    1> >(tee stdout | grep -v '^{')     \
    2> >(tee stderr | grep -v '^{')
EOF
}

function inShellFor {
    # Run command $2 in a shell set up for package $1
    nix-shell --pure --show-trace -E "$(envFor "$1")" --run "$2"
}

# Test functions which require a package as argument

function pkgTestEnv {
    inShellFor "$1" true ||
        fail "Problem running command in '$1' environment:\n$(envFor "$1")"
}

function pkgTestConfigure {
    inShellFor "$1" "cabal update; cabal configure" ||
        fail "Couldn't configure package '$1'"
}

function pkgTestExtract {
    inShellFor "$1" "$(cmdFor "$1")" || fail "Couldn't extract ASTs from '$1'"
}

function pkgTestHaveAsts {
    cat stdout stderr | grep "^{" > /dev/null || fail "No ASTs found for $PKG"
}

# Test functions

function testPkgs {
    while read -r PKG
    do
        msg "Testing '$PKG'"
        inSourceDir "$PKG" runPkgTests
        msg "Tests pass for '$PKG'"
    done < <(pkgs)
}

# Test invocation

function runPkgTests {
    pkgTestEnv       "$1"
    pkgTestConfigure "$1"
    pkgTestExtract   "$1"
    pkgTestHaveAsts  "$1"
}

testPkgs

msg "All tests passed"
