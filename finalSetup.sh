set -e

KERNEL_VER="$1"

make -j"$(nproc)"

sudo make modules_install

sudo make install


if command -v update-grub >/dev/null 2>&1; then
    sudo update-grub
elif command -v grub2-mkconfig >/dev/null 2>&1; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
else
    echo "Could not detect grub update command. Update manually!"
fi


echo "Kernel install complete. Available kernels:"
grep "menuentry '" /boot/grub/grub.cfg || true

echo "Reboot into the new kernel with: sudo reboot"

