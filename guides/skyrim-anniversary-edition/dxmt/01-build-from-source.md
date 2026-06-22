# Build DXMT from source (macOS / Apple Silicon)

Produces x86_64 DXMT: `d3d11.dll`, `dxgi.dll`, `d3d10core.dll`, `winemetal.dll`, `winemetal.so`.

Host Wine (FOSS CrossOver-sources 26) is built separately — see [02-build-host-wine.md](02-build-host-wine.md).

## Prerequisites

```sh
brew install meson ninja cmake mingw-w64 git curl
# Xcode (16+) installed, then the Metal toolchain component (used by airconv):
xcodebuild -downloadComponent MetalToolchain
```

## 1. Clone DXMT (submodules are required)

```sh
git clone --recurse-submodules https://github.com/3Shain/dxmt ~/dxmt-build/dxmt
mkdir -p ~/dxmt-build/toolchains
```

## 2. Build x86_64 LLVM 15.0.7 (airconv's shader compiler)

```sh
git clone --depth 1 --branch llvmorg-15.0.7 \
  https://github.com/llvm/llvm-project.git ~/dxmt-build/toolchains/llvm-project

cmake -B ~/dxmt-build/toolchains/llvm-darwin-build -S ~/dxmt-build/toolchains/llvm-project/llvm \
  -DCMAKE_INSTALL_PREFIX="$HOME/dxmt-build/toolchains/llvm-darwin" \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 -DLLVM_HOST_TRIPLE=x86_64-apple-darwin \
  -DLLVM_ENABLE_ASSERTIONS=On -DLLVM_ENABLE_ZSTD=Off -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD="" -DLLVM_BUILD_TOOLS=Off -DLLVM_INCLUDE_TESTS=Off \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -G Ninja

ninja -C ~/dxmt-build/toolchains/llvm-darwin-build
ninja -C ~/dxmt-build/toolchains/llvm-darwin-build install
```

## 3. Fetch the 3Shain Wine fork (winemetal.so links against it)

```sh
mkdir -p ~/dxmt-build/toolchains/wine
curl -L https://github.com/3Shain/wine/releases/download/v8.16-3shain/wine.tar.gz \
  | tar -zx -C ~/dxmt-build/toolchains/wine
```

## 4. Fetch llvm-mingw (puts it on PATH to select the clang cross build)

```sh
curl -L https://github.com/mstorsjo/llvm-mingw/releases/download/20251216/llvm-mingw-20251216-ucrt-macos-universal.tar.xz \
  | tar -xJ -C ~/dxmt-build/toolchains
```

## 5. Build DXMT

```sh
export PATH="$HOME/dxmt-build/toolchains/llvm-mingw-20251216-ucrt-macos-universal/bin:$PATH"
cd ~/dxmt-build/dxmt

meson setup --cross-file build-win64.txt \
  -Denable_nvapi=true -Denable_nvngx=true \
  -Dnative_llvm_path="$HOME/dxmt-build/toolchains/llvm-darwin" \
  -Dwine_install_path="$HOME/dxmt-build/toolchains/wine" \
  build --buildtype debugoptimized

meson compile -C build
```

## Output

```
build/src/d3d11/d3d11.dll
build/src/dxgi/dxgi.dll
build/src/d3d10/d3d10core.dll
build/src/winemetal/winemetal.dll
build/src/winemetal/unix/winemetal.so
```
