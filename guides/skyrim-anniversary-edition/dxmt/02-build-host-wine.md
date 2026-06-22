# Build host Wine: FOSS CrossOver-sources 26 (macOS / Apple Silicon)

Builds x86_64 Wine 11.0 from CrossOver's published sources — the host that runs DXMT. (DXMT's guide:
"a FOSS CrossOver Wine 24+ built from the sources is sufficient.") Installs to `~/cx-wine`.

## Prerequisites

x86_64 Homebrew (separate from the arm64 install, at `/usr/local`) with the build deps:

```sh
arch -x86_64 /usr/local/bin/brew install freetype bison mingw-w64 sdl2
```

## 1. Download + extract the Wine source

```sh
curl -L -o /tmp/cx26.tar.gz \
  https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.0.0.tar.gz
mkdir -p ~/cx-wine-build
tar xzf /tmp/cx26.tar.gz -C ~/cx-wine-build sources/wine
```

## 2. Patch win32u/vulkan.c

We configure `--without-vulkan`, but CrossOver's `win32u/vulkan.c` uses `SONAME_LIBVULKAN`
unconditionally. Add a fallback so it compiles:

```sh
perl -0pi -e 's/(static void vulkan_init_once\(void\))/#ifndef SONAME_LIBVULKAN\n#define SONAME_LIBVULKAN "libvulkan.1.dylib"\n#endif\n\n$1/' \
  ~/cx-wine-build/sources/wine/dlls/win32u/vulkan.c
```

## 3. Configure, build, install (x86_64 under Rosetta)

```sh
arch -x86_64 /bin/bash -c '
  export PATH=/usr/local/opt/bison/bin:/usr/local/bin:/usr/bin:/bin
  export PKG_CONFIG_PATH=/usr/local/opt/freetype/lib/pkgconfig:/usr/local/opt/sdl2-compat/lib/pkgconfig
  export CPPFLAGS=-I/usr/local/include LDFLAGS=-L/usr/local/lib
  mkdir -p ~/cx-wine-build/build && cd ~/cx-wine-build/build
  ../sources/wine/configure --enable-archs=x86_64 --disable-tests --without-gstreamer
  make -j6
  make install DESTDIR="$HOME/cx-wine"
'
```

## Output

```
~/cx-wine/usr/local/bin/wine
```
