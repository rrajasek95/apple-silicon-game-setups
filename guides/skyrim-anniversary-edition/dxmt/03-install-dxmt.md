# Install DXMT into the host Wine

DXMT's guide **non-builtin** install. DLLs come from the build ([01](01-build-from-source.md)) or a
release tarball. `$WROOT` = host Wine ([02](02-build-host-wine.md), e.g. `~/cx-wine/usr/local`),
`$PFX` = the Wine prefix.

```sh
WROOT=~/cx-wine/usr/local
PFX=~/dxmt-skyrim-prefix
DXMT=~/dxmt-build/dxmt/build/src      # a release tarball is flatter: <dxmt>/x86_64-windows + x86_64-unix
```

## Place the DLLs

```sh
# winemetal stays builtin (its unixlib only loads when winemetal is loaded as builtin)
cp "$DXMT"/winemetal/unix/winemetal.so "$WROOT/lib/wine/x86_64-unix/"
cp "$DXMT"/winemetal/winemetal.dll     "$WROOT/lib/wine/x86_64-windows/"
cp "$DXMT"/winemetal/winemetal.dll     "$PFX/drive_c/windows/system32/"

# d3d11 / dxgi / d3d10core: native files in system32
cp "$DXMT"/d3d11/d3d11.dll      "$PFX/drive_c/windows/system32/"
cp "$DXMT"/dxgi/dxgi.dll        "$PFX/drive_c/windows/system32/"
cp "$DXMT"/d3d10/d3d10core.dll  "$PFX/drive_c/windows/system32/"
```

## Override (run the game with this)

```sh
export WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b"
```

The guide's other mode (builtin: DLLs in `lib/wine` only, no override) needs a `d3d11` builtin/fakedll,
which a Wine built `--without-vulkan` (no wined3d) does not have — so use the non-builtin mode above.
