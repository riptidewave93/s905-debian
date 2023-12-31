# Recompile with:
# mkimage -C none -A arm -T script -d boot.cmd boot.scr

# Set local vars
setenv ramdisk "initrd.img-KERNELVER"
setenv kernel "vmlinuz-KERNELVER"
setenv bootpart_uuid "PLACEHOLDERUUID"
setenv extra_cmdline "net.ifnames=0 fsck.repair=yes panic=3 boot.dtb=${fdtfile}"

# Import and load any custom settings
if test -e ${devtype} ${devnum}:${distro_bootpart} config.txt; then
	load ${devtype} ${devnum}:${distro_bootpart} ${pxefile_addr_r} config.txt
	env import -t ${pxefile_addr_r} ${filesize}
fi

# Load FDT
load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${fdtfile}

# Set cmdline
setenv bootargs root=PARTUUID=${bootpart_uuid}-02 rw rootwait ${extra_cmdline}

# Boot our image
load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} ${kernel}
setenv kernel_comp_size ${filesize}
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} ${ramdisk}
setenv ramdisk_size ${filesize}

# Boot the system
booti ${kernel_addr_r} ${ramdisk_addr_r}:${ramdisk_size} ${fdt_addr_r}
