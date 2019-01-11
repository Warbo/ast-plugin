with import ./nixpkgs.nix;
with lib;
with rec {
  haskellSrc = name: version:
    (haskellPackages.callPackage
      (haskellPackages.callHackage name version) {}).src;

  env = pkgName: {
    inherit pkgName;
    buildInputs = [
      cabal-install
      (haskellPackages.ghcWithPackages (hs: [
        hs.AstPlugin
        hs.ghc-paths # Fix for https://github.com/NixOS/nixpkgs/issues/6419
        (getAttr pkgName hs)
      ]))
      installHackage
    ];
  };

  pkgTests = pkgName: version:
    with rec {
      mkTest = extraEnv: tst: script: runCommand "pkgTest-${tst}"
        (env pkgName // extraEnv)
        ''
          mkdir scratch; cd scratch

          echo "Copying Cabal index" 1>&2
          export HOME="$PWD"
          installHackage
          chmod 777 -R "$HOME/.cabal"
          rm -f "$HOME/.cabal/packages/hackage.haskell.org/hackage-security-lock" ||
            true

          cp -r "${haskellSrc pkgName version}" ./src
          chmod 777 -R ./src
          cd ./src
          CODE=0
          ${script}
          [[ -e "$out" ]] || mkdir "$out"
          exit "$CODE"
        '';

      envTest = mkTest {} "env" ''
        echo "Checking environment works for '$pkgName'" 1>&2
        true
      '';

      configTest = mkTest { inherit envTest; } "config" ''
        echo "Checking that we can configure '$pkgName'" 1>&2
        cabal new-configure
      '';

      extractTest = mkTest { inherit configTest; } "extract" ''
        set -e
        echo "Checking that we can extract ASTs for '$pkgName'" 1>&2

        export HOME="$PWD"
        GHC_PKG=$(ghc-pkg list | head -n 1 | tr -d ':')
        OPTIONS="-package-db=$GHC_PKG -package AstPlugin -fplugin=AstPlugin.Plugin"
        cabal --ghc-options="$OPTIONS" new-build 1> stdout 2> stderr || CODE=1

        echo "Stdout of cabal new-build" 1>&2
        grep -v "^{" < stdout 1>&2
        echo "Stderr of cabal new-build" 1>&2
        grep -v "^{" < stderr 1>&2
        echo "Extracted output written to '$out'" 1>&2
        grep '^{' < stderr > "$out"
      '';
    };
    extractTest;

  tests = mapAttrs pkgTests { list-extras = "0.4.1.4"; };
};

withDeps (allDrvsIn tests) (dummyBuild "astplugin-tests")
