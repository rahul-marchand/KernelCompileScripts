#!/bin/bash
# Detects bare minimum kernel config needs for AWS VMs
# Discovery-only, does not edit .config
#
# Usage: ./checkVM.sh [--parseable]
# --parseable: Output in format CONFIG_OPTION=required for script parsing

PARSEABLE=false
if [[ "$1" == "--parseable" ]]; then
    PARSEABLE=true
fi

output_config() {
    local config="$1"
    local level="$2"  # required or optional
    if $PARSEABLE; then
        echo "$config=$level"
    else
        echo " -> Ensure $config=y"
    fi
}

output_section() {
    local section="$1"
    if ! $PARSEABLE; then
        echo
        echo "=== $section ==="
    fi
}

output_info() {
    local info="$1"
    if ! $PARSEABLE; then
        echo "$info"
    fi
}

output_section "Root Filesystem"
ROOTFS=$(findmnt -n -o FSTYPE /)
output_info "Root filesystem: $ROOTFS"
case $ROOTFS in
  ext4)  output_config "CONFIG_EXT4_FS" "required";;
  xfs)   output_config "CONFIG_XFS_FS" "required";;
  btrfs) output_config "CONFIG_BTRFS_FS" "required";;
  *)     output_info "Check kernel option for $ROOTFS filesystem";;
esac

output_section "Block Devices"
if ! $PARSEABLE; then
    lsblk -d -o NAME,MODEL
fi
if lspci -nn | grep -qi nvme; then
  output_info "NVMe detected"
  output_config "CONFIG_BLK_DEV_NVME" "required"
elif lsmod | grep -qi virtio_blk; then
  output_info "Virtio block detected"
  output_config "CONFIG_VIRTIO_BLK" "required"
elif lsmod | grep -qi xen_blkfront; then
  output_info "Xen block frontend detected"
  output_config "CONFIG_XEN_BLKDEV_FRONTEND" "required"
else
  output_info "Could not auto-detect block device driver, check manually."
fi

output_section "Network Interfaces"
NIC_IF=$(ip -o -4 route show to default | awk '{print $5}')
NIC_DRIVER=$(ethtool -i "$NIC_IF" 2>/dev/null | grep driver | awk '{print $2}')
output_info "Default network interface ($NIC_IF) driver: $NIC_DRIVER"
case $NIC_DRIVER in
  virtio_net)    output_config "CONFIG_VIRTIO_NET" "required";;
  xen-netfront)  output_config "CONFIG_XEN_NETDEV_FRONTEND" "required";;
  ena)           
    output_info "(AWS Elastic Network Adapter)"
    output_config "CONFIG_ENA_ETHERNET" "required";;
  *)             output_info "Check kernel option for $NIC_DRIVER";;
esac

output_section "Boot Environment (EFI vs BIOS)"
if [ -d /sys/firmware/efi ]; then
  output_info "EFI/UEFI boot detected"
  output_config "CONFIG_EFI" "required"
  output_config "CONFIG_EFI_PARTITION" "required"
else
  output_info "Legacy BIOS/PV boot detected"
  output_config "CONFIG_MSDOS_PARTITION" "required"
fi

output_section "Init / Misc"
output_config "CONFIG_DEVTMPFS" "required"
output_config "CONFIG_DEVTMPFS_MOUNT" "required"
output_config "CONFIG_TMPFS" "required"
output_config "CONFIG_UNIX" "required" 
output_config "CONFIG_INET" "required"
output_config "CONFIG_TTY" "required"
output_config "CONFIG_VT" "required"
output_config "CONFIG_CONSOLE" "required"

