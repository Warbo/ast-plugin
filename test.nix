with import <nixpkgs> {};
with builtins;
with lib;

let astPlugin = runCommand "cabal2nix-ast-plugin"
                           { buildInputs = [ haskellPackages.cabal2nix ];
                             SOURCE      = ./.;
                             NIX_REMOTE  = "daemon";
                             NIX_PATH    = builtins.getEnv "NIX_PATH"; }
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

                             cp -r "$SOURCE" ./AstPlugin
                             chmod -R +w ./AstPlugin
                             rm -rf ./AstPlugin/dist

                             pushd ./AstPlugin > /dev/null
                             cabal2nix ./. > default.nix
                             popd > /dev/null

                             cp -r ./AstPlugin "$out"
                           '';
    get = name: "cabal get ${name}";
    env = name: {
                  buildInputs = [
                    (haskellPackages.ghcWithPackages (hsPkgs: [
                      hsPkgs.cabal-install
                      hsPkgs."${name}"
                      (hsPkgs.callPackage "${astPlugin}" {})
                    ]))
                  ];
                };
    cmd = name: ''
      set -x
      set -e
      export HOME="$PWD"
      GHC_PKG=$(ghc-pkg list | head -n 1 | tr -d ':')
      OPTIONS="-package-db=$GHC_PKG -package AstPlugin -fplugin=AstPlugin.Plugin"
      cabal --ghc-options="$OPTIONS" -v build 1> stdout 2> stderr
      cat stdout stderr | grep -c "^{"
    '';

    pkgTests = name: mapAttrs (tst: script:
                                runCommand "pkgTest-${tst}" (env name) ''
                                  set -e
                                  mkdir scratch
                                  pushd scratch
                                  export HOME="$PWD"
                                  cabal update
                                  cabal get "${name}"
                                  pushd ${name}*
                                  ${script}
                                  touch "$out"
                                '') {
      env      = ''true'';
      config   = ''cabal update && cabal configure'';
      extract  = cmd name;
    };

    pkgs = [ "list-extras" "text" "vector" "Cabal" "attoparsec"
             "http-client" ];
    tests = concatMap (name: attrValues (pkgTests name)) pkgs;
 in runCommand "dummy" { src = ./.; buildInputs = tests; } ''touch "$out"''
