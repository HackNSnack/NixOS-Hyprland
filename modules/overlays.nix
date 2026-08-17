{ inputs, ... }:
{
  nixpkgs.overlays = [
    # Neovim nightly overlay disabled: it tracks neovim's master branch
    # (true nightly builds), not stable releases, and broke plugins.
    # nixpkgs' own neovim is used instead. To re-enable nightly:
    # inputs.neovim-nightly.overlays.default

    # Ollama - latest stable binary release (CPU-only build, no NVIDIA needed)
    # Binary bundles CUDA/Vulkan runtime stubs; autoPatchelfIgnoreMissingDeps
    # lets it build on CPU-only systems. GPU acceleration is picked up
    # automatically when an NVIDIA/Vulkan driver is present.
    # Update: bump version + hash, find latest at https://github.com/ollama/ollama/releases
    (final: prev: {
      ollama = final.stdenv.mkDerivation rec {
        pname = "ollama";
        version = "0.20.3";
        src = final.fetchurl {
          url = "https://github.com/ollama/ollama/releases/download/v${version}/ollama-linux-amd64.tar.zst";
          hash = "sha256-1nOAYN6WizxUJp1jZxxDI/3z0QW2m5iIYufwaBbHBn4=";
        };
        sourceRoot = ".";
        nativeBuildInputs = [ final.autoPatchelfHook final.zstd final.addDriverRunpath final.makeWrapper ];
        buildInputs = [ final.stdenv.cc.cc.lib final.zlib ];
        autoPatchelfIgnoreMissingDeps = [
          "libcuda.so.1"    # provided by NVIDIA driver at runtime (optional)
          "libvulkan.so.1"  # provided by vulkan-loader at runtime (optional)
        ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/lib
          cp -r bin/ollama $out/bin/
          cp -r lib/ollama $out/lib/
          runHook postInstall
        '';
        postFixup = ''
          # Add NVIDIA driver libs so ollama can find libcuda.so.1 at runtime.
          # Harmless on CPU-only systems (path just doesn't exist).
          wrapProgram $out/bin/ollama \
            --prefix LD_LIBRARY_PATH : "${final.addDriverRunpath.driverLink}/lib"
        '';
        meta = with final.lib; {
          description = "Get up and running with large language models locally";
          homepage = "https://ollama.com";
          license = licenses.mit;
          platforms = [ "x86_64-linux" ];
          mainProgram = "ollama";
        };
      };
    })

    # Moon v2.x - nixpkgs 26.05 ships 1.x; use the official pre-built musl
    # binary instead of compiling from source (Rust builds eat several GB of RAM).
    # To update: bump version + hash (get new hash from the .sha256 file on the
    # GitHub release page, then convert: echo <hex> | xxd -r -p | base64).
    (final: prev: {
      moon = final.stdenv.mkDerivation rec {
        pname = "moon";
        version = "2.1.1";
        src = final.fetchurl {
          url = "https://github.com/moonrepo/moon/releases/download/v${version}/moon_cli-x86_64-unknown-linux-musl.tar.xz";
          hash = "sha256-DrBtcpX5lGILS9d4gDxrpipM9epzEK5q1XOSxqi/6qg=";
        };
        # musl = fully static binary; no autoPatchelfHook or extra libs needed.
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          install -Dm755 moon $out/bin/moon
          runHook postInstall
        '';
        meta = with final.lib; {
          description = "Build system and monorepo management tool for the web ecosystem";
          homepage = "https://moonrepo.dev";
          license = licenses.mit;
          platforms = [ "x86_64-linux" ];
          mainProgram = "moon";
        };
      };
    })

    # Claude Code - always latest from dedicated flake
    # Update with: nix flake lock --update-input claude-code
    inputs.claude-code.overlays.default

    # llama.cpp - latest stable binary release (Vulkan backend, GPU-accelerated)
    # Update: bump version + hash, find latest at https://github.com/ggml-org/llama.cpp/releases
    # No Linux CUDA binary available upstream; Vulkan works with NVIDIA at runtime
    (final: prev: {
      llama-cpp = final.stdenv.mkDerivation rec {
        pname = "llama-cpp";
        version = "b8882";
        src = final.fetchurl {
          url = "https://github.com/ggml-org/llama.cpp/releases/download/${version}/llama-${version}-bin-ubuntu-vulkan-x64.tar.gz";
          hash = "sha256-bRsPDoMTVr/xLNP9V7/IF2Jiloax7oaF3hhl9ywoV2A=";
        };
        sourceRoot = "llama-${version}";
        nativeBuildInputs = [ final.autoPatchelfHook final.addDriverRunpath final.makeWrapper ];
        buildInputs = [ final.stdenv.cc.cc.lib final.zlib final.vulkan-loader final.openssl ];
        autoPatchelfIgnoreMissingDeps = [
          "libcuda.so.1"    # provided by NVIDIA driver at runtime
          "libvulkan.so.1"  # provided by vulkan-loader at runtime
        ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/lib
          cp llama-* $out/bin/
          cp *.so* $out/lib/
          # Backend plugins must be adjacent to the binaries (original release layout)
          cp libggml-*.so $out/bin/
          runHook postInstall
        '';
        postFixup = ''
          for bin in $out/bin/llama-*; do
            wrapProgram "$bin" \
              --prefix LD_LIBRARY_PATH : "${final.addDriverRunpath.driverLink}/lib:${final.vulkan-loader}/lib"
          done
        '';
        meta = with final.lib; {
          description = "Inference of LLaMA model in pure C/C++";
          homepage = "https://github.com/ggml-org/llama.cpp";
          license = licenses.mit;
          platforms = [ "x86_64-linux" ];
        };
      };
    })

    # Ollama - latest stable binary release (bundled CUDA/Vulkan)
    # Update: bump version + hash, find latest at https://github.com/ollama/ollama/releases
    (final: prev: {
      ollama = final.stdenv.mkDerivation rec {
        pname = "ollama";
        version = "0.21.0";
        src = final.fetchurl {
          url = "https://github.com/ollama/ollama/releases/download/v${version}/ollama-linux-amd64.tar.zst";
          hash = "sha256-p/xCYSmK7Kj3hfaVl4pemXAE1BTBPUz7lloQ2p9Ntuo=";
        };
        sourceRoot = ".";
        nativeBuildInputs = [ final.autoPatchelfHook final.zstd final.addDriverRunpath final.makeWrapper ];
        buildInputs = [ final.stdenv.cc.cc.lib final.zlib ];
        autoPatchelfIgnoreMissingDeps = [
          "libcuda.so.1"    # provided by NVIDIA driver at runtime
          "libvulkan.so.1"  # provided by vulkan-loader at runtime
        ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/lib
          cp -r bin/ollama $out/bin/
          cp -r lib/ollama $out/lib/
          runHook postInstall
        '';
        postFixup = ''
          # Add NVIDIA driver libs so ollama can find libcuda.so.1 at runtime
          wrapProgram $out/bin/ollama \
            --prefix LD_LIBRARY_PATH : "${final.addDriverRunpath.driverLink}/lib"
        '';
        meta = with final.lib; {
          description = "Get up and running with large language models locally";
          homepage = "https://ollama.com";
          license = licenses.mit;
          platforms = [ "x86_64-linux" ];
          mainProgram = "ollama";
        };
      };
    })

    (final: prev: rec {
      waybar-weather = final.callPackage ../pkgs/waybar-weather.nix { };
      # Helper: provide a clean cxxopts.pc to avoid broken upstream pc requiring non-existent icu-cu
      cxxoptsPcShim = final.runCommand "cxxopts-pc-shim" { } ''
                mkdir -p $out/lib/pkgconfig
                cat > $out/lib/pkgconfig/cxxopts.pc <<'EOF'
        prefix=${final.cxxopts}
        includedir=${final.cxxopts}/include

        Name: cxxopts
        Description: C++ command line parser headers
        Version: ${final.cxxopts.version}
        Cflags: -I${final.cxxopts}/include
        Libs:
        Requires:
        EOF
      '';
      # Allow argtable to configure with newer CMake by declaring policy minimum
      argtable = prev.argtable.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
        ];
      });

      # Specifically patch the nested attribute path used by nixpkgs: antlr4_9.runtime.cpp
      # Add the policy flag and patch CMakeLists to bump minimum and force NEW policies
      antlr4_9 = prev.antlr4_9 // {
        runtime = prev.antlr4_9.runtime // {
          cpp = prev.antlr4_9.runtime.cpp.overrideAttrs (old: {
            cmakeFlags = (old.cmakeFlags or [ ]) ++ [
              "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
            ];
            postPatch = (old.postPatch or "") + ''
              # Bump CMake minimum and force modern policies
              if [ -f runtime/Cpp/runtime/CMakeLists.txt ]; then
                sed -i -E 's/cmake_minimum_required\(VERSION [0-9.]+\)/cmake_minimum_required(VERSION 3.5)/' runtime/Cpp/runtime/CMakeLists.txt
                sed -i -E 's/(cmake_policy\(SET CMP[0-9]+ )OLD/\1NEW/g' runtime/Cpp/runtime/CMakeLists.txt || true
                sed -i -E 's/(CMAKE_POLICY\(SET CMP[0-9]+ )OLD/\1NEW/g' runtime/Cpp/runtime/CMakeLists.txt || true
              fi
              if [ -f runtime/Cpp/CMakeLists.txt ]; then
                sed -i -E 's/cmake_minimum_required\(VERSION [0-9.]+\)/cmake_minimum_required(VERSION 3.5)/' runtime/Cpp/CMakeLists.txt
                sed -i -E 's/(cmake_policy\(SET CMP[0-9]+ )OLD/\1NEW/g' runtime/Cpp/CMakeLists.txt || true
                sed -i -E 's/(CMAKE_POLICY\(SET CMP[0-9]+ )OLD/\1NEW/g' runtime/Cpp/CMakeLists.txt || true
              fi
            '';
          });
        };
      };

      # Fix libvdpau-va-gl CMake minimum for modern CMake
      libvdpau-va-gl = prev.libvdpau-va-gl.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
        ];
        postPatch = (old.postPatch or "") + ''
          # Bump top-level CMake minimum if present
          if [ -f CMakeLists.txt ]; then
            sed -i -E 's/cmake_minimum_required\(VERSION [0-9.]+\)/cmake_minimum_required(VERSION 3.5)/' CMakeLists.txt || true
          fi
        '';
      });

      # Pin pnpm to Node.js 22 — in 26.05 pnpm's generic.nix takes `nodejs`
      # directly (the old nodejs-slim parameter was removed in the 26.05 rewrite).
      pnpm = prev.pnpm.override { nodejs = final.nodejs_22; };

      # redisinsight hard-pins nodejs-slim_20 as a callPackage argument.
      # Override it to nodejs-slim_22 so we don't need permittedInsecurePackages.
      # redisinsight = prev.redisinsight.override { nodejs-slim_20 = final.nodejs-slim_22; };

      # Work around pamixer failing to find cxxopts via pkg-config (bogus icu-cu requirement)
      pamixer = prev.pamixer.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          final."pkg-config"
          cxxoptsPcShim
        ];
        # Ensure our shim takes precedence over any other cxxopts.pc
        preConfigure = (old.preConfigure or "") + ''
          export PKG_CONFIG_PATH=${cxxoptsPcShim}/lib/pkgconfig:"$PKG_CONFIG_PATH"
        '';
      });
    })
  ];
}
