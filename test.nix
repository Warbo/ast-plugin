with builtins;
with import ((import <nixpkgs> { config = {}; }).fetchgit {
  url    = http://chriswarbo.net/git/nix-config.git;
  rev    = "ce03e5e";
  sha256 = "1qg4ihf5w7xzsk1cdba7kzdl34jmdzvaf7vr6x0r86zgxn0zc5yj";
}) {};
with lib;
with rec {
  astPlugin = runCabal2nix {
    name = "AstPlugin";
    url  = ./.;
  };
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
    CODE=0
    export HOME="$PWD"
    GHC_PKG=$(ghc-pkg list | head -n 1 | tr -d ':')
    OPTIONS="-package-db=$GHC_PKG -package AstPlugin -fplugin=AstPlugin.Plugin"
    cabal --ghc-options="$OPTIONS" -v build 1> stdout 2> >(tee stderr >&2) || CODE=1
    cat stdout stderr | grep -c "^{"
    exit "$CODE"
  '';

  pkgTests = name:
    with {
      src = if haskellPackages."${name}" ? src
               then ''tar xf "${haskellPackages.${name}.src}"''
               else ''cabal get "${name}"'';
    };
    mapAttrs (tst: script: runCommand "pkgTest-${tst}" (env name) ''
               mkdir scratch
               cd scratch
               export HOME="$PWD"
               cabal update
               ${src}
               cd ${name}*
               ${script}
               touch "$out"
             '')
             {
               env      = ''true'';
               config   = ''cabal update && cabal configure'';
               extract  = cmd name;
             };

  pkgs  = [ "list-extras" "text" "vector" "Cabal" "attoparsec" "http-client" ];
  tests = concatMap (name: attrValues (pkgTests name)) pkgs;
};
withDeps tests (dummyBuild "astplugin-tests")
