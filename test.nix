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
with rec {
  astPlugin = import (runCabal2nix {
    name = "AstPlugin";
    url  = ./.;
  });
  env = name: {
                buildInputs = [
                  (haskellPackages.ghcWithPackages (hsPkgs: [
                    hsPkgs.cabal-install
                    (getAttr name hsPkgs)
                    (hsPkgs.callPackage astPlugin {})
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
