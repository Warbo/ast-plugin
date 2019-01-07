with builtins;
with rec {
  pinnedSrc = fetchTarball {
    name   = "nixpkgs1709";
    url    = https://github.com/NixOS/nixpkgs/archive/17.09.tar.gz;
    sha256 = "0kpx4h9p1lhjbn1gsil111swa62hmjs9g93xmsavfiki910s73sh";
  };

  pinned = import pinnedSrc { config = {}; overlays = []; };

  nix-helpers = pinned.fetchgit {
    url    = http://chriswarbo.net/git/nix-helpers.git;
    rev    = "148bd5e";
    sha256 = "0wywgdmv4gllarayhwf9p41pzrkvgs32shqrycv2yjkwz321w8wl";
  };
};
with import "${pinnedSrc}" {
  config   = {};
  overlays = [ (import "${nix-helpers}/overlay.nix") ];
};
with lib;
with { inherit (haskellPackages) haskellSrc2nix; };
with rec {
  HS2AST = haskellSrc2nix {
    name = "HS2AST";
    src  = fetchgit {
      url    = http://chriswarbo.net/git/hs2ast.git;
      rev    = "f48063e";
      sha256 = "1jg62a71mlnm0k2sjbjhf3n5q2c4snlbaj5dlrhdg44kxiyilx9x";
    };
  };

  astPlugin = haskellSrc2nix {
    name = "AstPlugin";
    src  = filterSource (path: type: !(elem (baseNameOf path) [
                                       ".git" ".gitignore" "dist"
                                       "dist-newstyle" "README" "result"
                                       "test.nix"
                                     ]))
                        ./.;
  };

  hsPackages = nixpkgs1603.haskellPackages.override (old: {
    overrides = self: super:
      with {
        fromHackage = name: version:
          self.callPackage (haskellPackages.hackage2nix name version);
      };
      {
        AstPlugin  = self.callPackage astPlugin          {};
        attoparsec = fromHackage "attoparsec" "0.13.0.1" {
          mkDerivation = args: self.mkDerivation
            (removeAttrs args [ "benchmarkHaskellDepends" ]/* // {
              libraryHaskellDepends = args.libraryHaskellDepends ++
                                      args.benchmarkHaskellDepends;
            }*/);
        };
        HS2AST     = self.callPackage HS2AST             {};
        tasty      = fromHackage "tasty"      "0.11.2.1" {};
        text       = fromHackage "text"       "1.2.2.1"  {};
      };
  });

  env = pkgName: {
    inherit pkgName;
    buildInputs = [
      cabal-install
      (hsPackages.ghcWithPackages (hs: [
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

          cp -r "${fetchFromHackage { inherit version; name = pkgName; }}" ./src
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
