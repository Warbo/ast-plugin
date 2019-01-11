with builtins;
with rec {
  pinned = overlays: import (fetchTarball {
    name   = "nixpkgs1709";
    url    = https://github.com/NixOS/nixpkgs/archive/17.09.tar.gz;
    sha256 = "0kpx4h9p1lhjbn1gsil111swa62hmjs9g93xmsavfiki910s73sh";
  }) { inherit overlays; config = {}; };

  nix-helpers =
    with pinned [];
    fetchgit {
      url    = http://chriswarbo.net/git/nix-helpers.git;
      rev    = "148bd5e";
      sha256 = "0wywgdmv4gllarayhwf9p41pzrkvgs32shqrycv2yjkwz321w8wl";
    };

  haskellPackages =
    with pinned [];
    haskell.packages.ghc7103.override (old: {
      overrides = self: super: {
        AstPlugin  = self.callPackage (self.haskellSrc2nix {
          name = "AstPlugin";
          src  = filterSource (path: type: !(elem (baseNameOf path) [
                                ".git" ".gitignore" "dist"
                                "dist-newstyle" "README" "result"
                                "test.nix"
                              ]))
                              ./.;
        }) {};

        HS2AST = self.callPackage (self.haskellSrc2nix {
          name = "HS2AST";
          src  = fetchgit {
            url    = http://chriswarbo.net/git/hs2ast.git;
            rev    = "f48063e";
            sha256 = "1jg62a71mlnm0k2sjbjhf3n5q2c4snlbaj5dlrhdg44kxiyilx9x";
          };
        }) {};
      };
    });
};
pinned [
  (import "${nix-helpers}/overlay.nix")
  (self: super: { inherit haskellPackages; })
]
