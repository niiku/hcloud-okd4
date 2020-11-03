#!/bin/sh
exec tail -n +3 $0
menuentry 'Install Fedora CoreOS' --class fedora --class gnu-linux --class gnu --class os {
	linux /boot/fcos-installer-kernel rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=sda coreos.inst.image_url=http://${ignition_hostname}/fcos-metal-bios.raw.gz coreos.inst.ignition_url=http://${ignition_hostname}/${server_role}.ign ip=${server_ip}::${server_gateway}:${server_netmask}:${server_hostname}:eth0:off nameserver=${server_nameserver}
	initrd /boot/fcos-initramfs.img /boot/rootfs.img
}