#!/bin/bash
set -e

docker_scripts_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scripts_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
. ${scripts_path}/vars.sh

# Make our temp builddir outside of the world of mounts for SPEEDS
uboot_builddir=$(mktemp -d)
unzip -q ${root_path}/downloads/${uboot_filename} -d ${uboot_builddir}

# Also setup FIP
fip_builddir=$(mktemp -d)
unzip -q ${root_path}/downloads/${fip_filename} -d ${fip_builddir}

# Exports baby
export PATH=${build_path}/toolchain/${toolchain_bin_path}:${PATH}
export GCC_COLORS=auto
export CROSS_COMPILE=${toolchain_cross_compile}
export ARCH=arm64

# Here we go
cd ${uboot_builddir}/${uboot_filename%.zip}

# If we have patches, apply them
if [[ -d ${root_path}/patches/u-boot/ ]]; then
    for file in ${root_path}/patches/u-boot/*.patch; do
        echo "Applying u-boot patch ${file}"
        patch -p1 < ${file}
    done
fi

# Apply overlay if it exists
if [[ -d ${root_path}/overlay/${uboot_overlay_dir}/ ]]; then
    echo "Applying ${uboot_overlay_dir} overlay"
    cp -R ${root_path}/overlay/${uboot_overlay_dir}/* ./
fi

# Each board gets it's own u-boot, so build each at a time
mkdir -p ${build_path}/uboot
for board in "${supported_devices[@]}"; do
    cfg=${board}
    cfg+="_defconfig"
    make distclean
    make ${cfg}
    #make menuconfig
    make -j`getconf _NPROCESSORS_ONLN`
    # AmLogic is special, we have to sign this crap to boot it
    fit_savedir=$(mktemp -d)
    cd ${fip_builddir}/${fip_filename%.zip}
    ./build-fip.sh ${board} ${uboot_builddir}/${uboot_filename%.zip}/u-boot.bin ${fit_savedir}
    # Generate our signed FIP to fit in the MBR space, cuz reasons
    dd if=${fit_savedir}/u-boot.bin.sd.bin of=${build_path}/uboot/${board}.fip conv=fsync,notrunc bs=1 count=440
    # And now get u-boot itself
    mv ${fit_savedir}/u-boot.bin ${build_path}/uboot/${board}.uboot
    rm -rf ${fit_savedir}
done
