# cuda.nix — why it's scoped the way it is, and how to debug it if it regresses

## What this module is actually for

Expose CUDA *runtime* shared libraries (`libcudart.so`, `libcublas.so`,
`libcudnn.so`, ...) to `nix-ld`, so that arbitrary pip-installed wheels
(PyTorch, TensorFlow, onnxruntime-gpu, ...) can dlopen CUDA at runtime even
though they weren't built by Nix. That's it. It does **not** install any ML
framework, and it should **not** change how the rest of the system's
packages get built.

`programs.nix-ld.libraries = [ cudaPackages.cuda_cudart ... ]` is sufficient
for that. `cudaPackages` is its own package set in nixpkgs — it is always
CUDA (that's the point of it) and is **not** gated by the global
`config.cudaSupport` flag.

## The footgun: `nixpkgs.config.cudaSupport = true;`

This is a *global* nixpkgs config flag, unrelated to `cudaPackages.*` above.
Its only effect is on packages that have an internal pattern like:

```nix
{ cudaSupport ? config.cudaSupport, ... }:
```

(opencv, ffmpeg-full, gstreamer plugins, pytorch's own build, magma, etc.)
Setting it globally flips CUDA on for *every one of those packages*
system-wide, not just the ones you care about.

This module used to set it, "to allow unfree CUDA packages" — but
`allowUnfree` (a different, unrelated flag) is what actually allows unfree
packages; `cudaSupport` does not gate unfree-ness. The line was doing
nothing useful for the nix-ld goal above, and had a very expensive side
effect: it silently forced `opencv4` to be built with CUDA, and:

- `frei0r-plugins` unconditionally depends on `opencv`
- `jellyfin-ffmpeg` (pulled in by the `jellyfin` service module) depends on
  `frei0r-plugins`
- `pillow-heif` (a python package) also depends on `opencv4`, and gets
  pulled in transitively by `imageio` → `waypaper`

CUDA-enabled OpenCV is a huge C++/CUDA build (codegen for every enabled CUDA
arch) and **cache.nixos.org does not build/cache that variant** — Hydra only
builds the plain (non-CUDA) opencv. So every time *anything* in the closure
changed enough to force re-evaluation of that subtree (a routine package
bump, adding/removing an unrelated package, `nixos-rebuild` after any
`nix flake update`, etc.), Nix had no substitute for opencv and rebuilt it
from source — 20-40+ minutes depending on hardware, every single time.

Removing the global flag makes `opencv4` resolve back to the plain
(cached) build. `cudaPackages.*` — what this module actually needs — is
completely unaffected either way, because it's a separate package set.

Other packages in this repo that *intentionally* want a local CUDA build
(e.g. `nvtopPackages.full`, `btop.override { cudaSupport = hasNvidia; }` in
`modules/packages.nix`) already opt in **per-package**, explicitly, at the
call site. That's the correct pattern — small, opt-in, doesn't cascade.
Don't "fix" opencv rebuilds by re-adding the global flag; if a specific
package needs CUDA, override it locally like those two do.

## How to reproduce/debug this class of problem yourself

The general technique: build the *evaluated* derivation graph for your
actual flake output (not just plain `nixpkgs#foo`, which won't reflect your
overlays/config), find the offending package's `.drv` in it, then walk
`inputDrvs` backwards to see what pulled it in. Finally check whether its
resolved output path is present on the binary cache.

### 1. Confirm the suspect package isn't in the binary cache

```bash
# What path would *plain* nixpkgs (no overlays/config) use? (sanity baseline)
nix why-depends --all /run/current-system nixpkgs#opencv

# What path does *your flake's actual* pkgs (with your overlays + config)
# resolve opencv to? This is the one that matters.
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      pkgs  = flake.nixosConfigurations.<host>.pkgs;
  in pkgs.opencv4.outPath
'

# Is THAT exact path fetchable from cache.nixos.org?
nix path-info --store https://cache.nixos.org /nix/store/<hash>-opencv-4.13.0
# no output / error => NOT cached => will be built from source locally
```

If the hash differs from what plain `nixpkgs#opencv` resolves to, something
in your overlays/config (allowUnfree, allowBroken, cudaSupport, an overlay
override, etc.) is changing that derivation's inputs.

### 2. Get the full derivation graph for your actual system closure

```bash
# Get the .drv path for your flake's toplevel (evaluates with your config)
nix eval --impure --expr '
  (builtins.getFlake (toString ./.)).nixosConfigurations.<host>.config.system.build.toplevel.drvPath
'

# Recursively dump every derivation that feeds into it as JSON
# (this is ~20-25k derivations, ~90MB of JSON — expect it to take a minute)
nix derivation show -r /nix/store/<hash>-nixos-system-<host>-<ver>.drv > /tmp/graph.json
```

### 3. Find the target package's `.drv` name(s) in that graph

```bash
python3 - <<'EOF'
import json
data = json.load(open('/tmp/graph.json'))["derivations"]
print(len(data), "derivations total")
hits = [k for k in data if 'opencv' in k.lower()]
print(hits)
EOF
```

### 4. Walk `inputDrvs` backwards (reverse dependency search)

There's no built-in "who depends on this .drv" query once you already have
the JSON dump — you have to scan for it:

```python
import json
data = json.load(open('/tmp/graph.json'))["derivations"]

def parents_of(target):
    return [name for name, d in data.items()
            if target in d.get("inputs", {}).get("drvs", {})]

frontier = ['<opencv-drv-name>.drv']
seen = set(frontier)
for _ in range(8):                      # walk up a handful of levels
    nxt = []
    for f in frontier:
        for p in parents_of(f):
            print(f, "<-", p)
            if p not in seen:
                seen.add(p); nxt.append(p)
    frontier = nxt
    if not frontier:
        break
```

This prints a chain like:

```
opencv.drv <- frei0r-plugins.drv
frei0r-plugins.drv <- jellyfin-ffmpeg.drv
jellyfin-ffmpeg.drv <- jellyfin.drv
jellyfin.drv <- unit-jellyfin.service.drv <- system-units.drv <- etc.drv <- toplevel.drv
```

...i.e. exactly which top-level package/module is dragging the expensive
thing in, and through how many layers of indirection.

### 5. Confirm the fix before committing to it

Re-run step 1's `nix eval` with the flag/override removed (or override
`config` inline in a throwaway `import nixpkgs { config = {...}; }` eval) and
check the output path changes to one that *is* on the cache:

```bash
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      pkgs = import flake.inputs.nixpkgs {
        system = "x86_64-linux";
        config = { allowUnfree = true; allowBroken = true; cudaSupport = false; };
        overlays = flake.nixosConfigurations.<host>.config.nixpkgs.overlays or [];
      };
  in pkgs.opencv4.outPath
'
nix path-info --store https://cache.nixos.org /nix/store/<new-hash>-opencv-4.13.0
```

If that second path-info succeeds, you've confirmed the fix substitutes
instead of building, without needing to actually run a full rebuild to find
out.

### General lesson for future package-set-wide flags

Any `nixpkgs.config.<flag> = true;` set in a NixOS module is global — it
affects every package in the closure that reads that flag, not just the
package(s) you added the module for. Before setting one, grep nixpkgs for
who reads it (`grep -rn "config.cudaSupport" $(nix eval --raw
nixpkgs#path)/pkgs`, or search on GitHub) and sanity-check the blast radius.
Prefer per-package `.override { flagName = true; }` at the call site instead
— that's what `nvtopPackages.full` / `btop.override { cudaSupport = ...; }`
in `modules/packages.nix` already do correctly.
