#!/bin/bash
#
# EC2 Custom Kernel Installation Verifier
#
# This script checks if a newly compiled kernel has been installed correctly
# and is configured properly for an EC2 environment before you reboot.
#
# Usage: ./verify_kernel_install.sh <KERNEL_VERSION>
# Example: ./verify_kernel_install.sh 6.6.42
#

# --- Configuration ---
# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Functions for printing status ---
print_success() {
    echo -e "${GREEN}[✔] SUCCESS:${NC} $1"
}

print_error() {
    echo -e "${RED}[✘] ERROR:${NC} $1"
    ((error_count++))
}

print_warning() {
    echo -e "${YELLOW}[!] WARNING:${NC} $1"
}

print_info() {
    echo -e "[-] INFO: $1"
}


# --- Script Start ---
# Check for kernel version argument
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <KERNEL_VERSION>${NC}"
    echo "Example: $0 6.6.42"
    exit 1
fi

KERNEL_VER="$1"
error_count=0

echo "--- Verifying Kernel Installation for version ${KERNEL_VER} ---"

# --- 1. Check for Kernel Files in /boot ---
print_info "Checking for essential files in /boot..."
BOOT_FILES=( "vmlinuz-${KERNEL_VER}" "initrd.img-${KERNEL_VER}" "config-${KERNEL_VER}" )
for file in "${BOOT_FILES[@]}"; do
    if [ -s "/boot/${file}" ]; then
        print_success "File '/boot/${file}' exists and is not empty."
    else
        print_error "File '/boot/${file}' is missing or empty."
    fi
done

# --- 2. Check GRUB Bootloader Configuration ---
print_info "Checking GRUB configuration..."
GRUB_CFG="/boot/grub/grub.cfg"
if [ ! -f "${GRUB_CFG}" ]; then
    print_error "GRUB config file not found at ${GRUB_CFG}."
else
    # Check if a menuentry for the new kernel exists
    if grep -q "menuentry '.*, with Linux ${KERNEL_VER}'" "${GRUB_CFG}"; then
        print_success "GRUB menuentry found for kernel ${KERNEL_VER}."

        # Check if the new kernel is the default (first) entry
        DEFAULT_KERNEL_ENTRY=$(grep -m 1 "menuentry '.*'" "${GRUB_CFG}")
        if [[ "${DEFAULT_KERNEL_ENTRY}" == *"${KERNEL_VER}"* ]]; then
            print_success "Kernel ${KERNEL_VER} is the default boot option."
        else
            print_warning "Kernel ${KERNEL_VER} is installed but is NOT the default boot option."
        fi
    else
        print_error "GRUB menuentry NOT found for kernel ${KERNEL_VER}. Run 'sudo update-grub'."
    fi
fi

# --- 3. Verify EC2-Specific Driver Configuration ---
print_info "Verifying kernel configuration for EC2 compatibility..."
CONFIG_FILE="/boot/config-${KERNEL_VER}"
if [ ! -f "${CONFIG_FILE}" ]; then
    print_error "Cannot perform EC2 driver check: config file is missing."
else
    EC2_DRIVERS=( "CONFIG_NVME_CORE=y" "CONFIG_VIRTIO_PCI=y" "CONFIG_VIRTIO_NET=y" )
    for driver in "${EC2_DRIVERS[@]}"; do
        if grep -q "^${driver}$" "${CONFIG_FILE}"; then
            print_success "EC2 driver config '${driver}' is correctly set."
        else
            print_error "EC2 driver config '${driver}' is NOT set to '=y' (built-in). This kernel will not boot!"
        fi
    done
fi


# --- Final Summary ---
echo "--------------------------------------------------------"
if [ "${error_count}" -gt 0 ]; then
    echo -e "${RED}SUMMARY: ${error_count} critical error(s) found.${NC}"
    echo -e "${RED}DO NOT REBOOT YOUR INSTANCE.${NC}"
    echo "Review the errors above to diagnose the issue."
else
    echo -e "${GREEN}SUMMARY: All checks passed!${NC}"
    echo "Your new kernel appears to be correctly installed and configured for EC2."
    echo "It should be safe to reboot now."
fi
echo "--------------------------------------------------------"

exit ${error_count}
