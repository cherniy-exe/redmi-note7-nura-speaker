#!/bin/bash
# Example build for the speaker patches (adjusted from the verified 7.2.15 build).
# Usage: KDIR=/path/to/linux-7.2.15 ./build-example.sh
set -eu
KDIR=${KDIR:?set KDIR to your clean sdm660-mainline 7.2.x tree}
REPO=$(cd "$(dirname "$0")" && pwd)
cd "$KDIR"

for p in "$REPO"/patches/*.patch; do
  echo "applying $(basename "$p")"
  git apply "$p"
done
scripts/config --module SND_SOC_MAX98927
git add -A
git -c user.email=local@example.com -c user.name=Local commit -m 'lavender: MAX98937 speaker via max98927'
git tag -f -a v7.2.15 -m v7.2.15 HEAD

# Optional rootless LLVM-19 toolchain: TOOLCHAIN_ROOT=/path/to/root ./build-example.sh
# Without it, plain clang-19/ld.lld-19 from PATH are used.
if [ -n "${TOOLCHAIN_ROOT:-}" ]; then
  export PATH="$TOOLCHAIN_ROOT/usr/bin:$PATH"
  export LD_LIBRARY_PATH="$TOOLCHAIN_ROOT/usr/lib/x86_64-linux-gnu"
  export M4="$TOOLCHAIN_ROOT/usr/bin/m4"
  export BISON_PKGDATADIR="$TOOLCHAIN_ROOT/usr/share/bison"
  export HOSTCFLAGS="-I$TOOLCHAIN_ROOT/usr/include -I$TOOLCHAIN_ROOT/usr/include/x86_64-linux-gnu"
  export HOSTLDFLAGS="-L$TOOLCHAIN_ROOT/usr/lib/x86_64-linux-gnu"
fi

make ARCH=arm64 LLVM=-19 olddefconfig
make ARCH=arm64 LLVM=-19 -j4 M=sound/soc/codecs modules
make ARCH=arm64 LLVM=-19 -j4 qcom/sdm660-xiaomi-lavender-tianma.dtb
zstd -19 -q -f -o snd-soc-max98927.ko.zst sound/soc/codecs/snd-soc-max98927.ko
echo "release: $(make -s ARCH=arm64 kernelrelease | tail -1)"
echo "module:  $(pwd)/snd-soc-max98927.ko.zst"
