# Test building TH code that needs DLLs when cross compiling for windows
{ stdenv, lib, util, project', haskellLib, recurseIntoAttrs, testSrc, compiler-nix-name, evalPackages, buildPackages }:

with lib;

let
  project = externalInterpreter: project' {
    inherit compiler-nix-name evalPackages;
    src = testSrc "th-dlls";
    cabalProjectLocal = builtins.readFile ../cabal.project.local;
    modules = [({pkgs, ...}: lib.optionalAttrs externalInterpreter {
      packages.th-dlls.components.library.ghcOptions = [ "-fexternal-interpreter" ];
      # Static openssl seems to fail to load in iserv for musl
      packages.HsOpenSSL.components.library.libs = lib.optional pkgs.stdenv.hostPlatform.isMusl (pkgs.openssl.override { static = false; });
    })];
  };

  packages = (project false).hsPkgs;
  packages-ei = (project true).hsPkgs;
  compareGhc = builtins.compareVersions buildPackages.haskell-nix.compiler.${compiler-nix-name}.version;

in recurseIntoAttrs {
  meta.disabled = stdenv.hostPlatform.isGhcjs ||
    # the macOS linker tries to load `clang++` :facepalm:
    (stdenv.hostPlatform.isDarwin && compareGhc "9.4.0" >= 0) ||
    # On aarch64 this test also breaks form musl builds (including cross compiles on x86_64-linux)
    (stdenv.hostPlatform.isAarch64 && stdenv.hostPlatform.isMusl) ||
    # broken on ucrt64 windows
    (stdenv.hostPlatform.libc == "ucrt")
    ;

  ifdInputs = {
    inherit (project true) plan-nix;
  };

  build = packages.th-dlls.components.library;
  build-profiled = packages.th-dlls.components.library.profiled;
  just-template-haskell = packages.th-dlls.components.exes.just-template-haskell;
  build-ei = packages-ei.th-dlls.components.library;
  build-profiled-ei = packages-ei.th-dlls.components.library.profiled;
  just-template-haskell-ei = packages-ei.th-dlls.components.exes.just-template-haskell;
}
