with import <nixpkgs> {};
with builtins;

let source    = ./.;
    astPlugin = runCommand "cabal2nix-ast-plugin"
                           { buildInputs = [ haskellPackages.cabal2nix nix ];
                             NIX_REMOTE  = "daemon";
                             NIX_PATH    = builtins.getEnv "NIX_PATH";}
                           ''set -e
                             if [[ -d "${source}" ]]
                             then
                               echo "Found '${source}'" 1>&2
                             else
                               echo "Couldn't find '${source}'" 1>&2
                               exit 2
                             fi

                             if command -v cabal2nix > /dev/null
                             then
                               echo "Found cabal2nix" 1>&2
                             else
                               echo "Couldn't find cabal2nix" 1>&2
                               exit 3
                             fi

                             cp -r "${source}" ./AstPlugin
                             chmod -R +w ./AstPlugin
                             rm -rf ./AstPlugin/dist

                             RESULT=$(nix-store --add ./AstPlugin)
                             echo "Stored AstPlugin at '$RESULT'" 1>&2
                             cabal2nix --shell "$RESULT" > "$out"'';
    envFor = pkg: cmd: runCommand "dummy" {
        buildInputs = [
          haskellPackages.cabal-install
          (haskellPackages.ghcWithPackages (hsPkgs: [
            hsPkgs."${pkg}"
            (hsPkgs.callPackage "${astPlugin}" {})
          ]))
        ];
      } cmd;
    testPkg = pkg: [
      (result pkg ''set -e; echo "true" > "$out"'')
      (result pkg ''
        set -e
        set -x
        "${gnutar}/bin/tar" xf "${haskellPackages."${pkg}".src}"
        chmod -R +w ./${pkg}*
        cd ./${pkg}*

        if [[ -z "$TMPDIR" ]]
        then
          echo "'TMPDIR' not set" 1>&2
          exit 5
        fi

        export HOME="$TMPDIR"
        cabal configure
        GHC_PKG=$(ghc-pkg list | head -n 1 | tr -d ':')
        OPTIONS="-package-db=$GHC_PKG -package AstPlugin -fplugin=AstPlugin.Plugin"
        cabal --ghc-options="$OPTIONS" -v build \
              1> >(tee stdout | grep -v '^{')     \
              2> >(tee stderr | grep -v '^{')
        echo "true" > "$out"
      '')
    ];
    result   = pkg: cmd: parse (unsafeDiscardStringContext (readFile "${envFor pkg cmd}"));
    checkPkg = pkg: all (x: x) (testPkg pkg);
    pkgNames = [ "list-extras" ];
    parse    = s: addErrorContext "Trying to parse '${s}'" (fromJSON s);
in assert (all checkPkg pkgNames); true
