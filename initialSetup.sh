#!/bin/bash


set -e

KERNEL_VER="$1"

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev bc wget git

#Note change v4.x as neeeded
wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VER}.tar.xz
tar -xf linux-${KERNEL_VER}.tar.xz
cd linux-${KERNEL_VER}


cp /boot/config-$(uname -r) .config

make oldconfig





