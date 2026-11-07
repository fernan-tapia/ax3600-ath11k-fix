#!/bin/sh
# Build ath11k.ko / ath11k_ahb.ko for the AX3600's OpenWrt 25.12.5 with patches 950-952.
# Uses the official config.buildinfo so the kernel vermagic matches the running firmware
# (6.12.94-1-dbd7ac5945a1d38dbc7f22bedd674e40) and the modules can be swapped in place.
#
# Host packages (Debian/Ubuntu):
#   sudo apt install build-essential flex bison gawk unzip rsync file wget swig bzip2 \
#        libncurses-dev zlib1g-dev libssl-dev python3-setuptools
set -eu

SRC=${SRC:-$HOME/src/openwrt}
BRANCH=ax3600-ath11k-fix
REL=https://downloads.openwrt.org/releases/25.12.5/targets/qualcommax/ipq807x
VERMAGIC=dbd7ac5945a1d38dbc7f22bedd674e40
OUT=$(cd "$(dirname "$0")" && pwd)/out

# WSL appends Windows paths with spaces, which break the OpenWrt build.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

cd "$SRC"
git checkout -q "$BRANCH"
./scripts/feeds update -a
./scripts/feeds install -a
curl -fsSL "$REL/config.buildinfo" -o .config
make defconfig

make -j"$(nproc)" tools/install toolchain/install
make -j"$(nproc)" target/linux/compile

got=$(cat build_dir/target-*/linux-qualcommax_ipq807x/linux-*/.vermagic)
if [ "$got" != "$VERMAGIC" ]; then
	echo "vermagic $got does not match the router ($VERMAGIC); not building modules" >&2
	exit 1
fi

make package/kernel/mac80211/clean
make -j"$(nproc)" package/kernel/mac80211/compile

mkdir -p "$OUT"
for m in ath11k ath11k_ahb; do
	find build_dir/target-*/linux-qualcommax_ipq807x/packages/ipkg-*/kmod-$m* \
		-name "$m.ko" -path '*/lib/modules/*' -exec cp -v {} "$OUT/" \;
done
ls -l "$OUT"
