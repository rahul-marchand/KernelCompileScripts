Scripts for personal use. Compiling Linux kernels for use on EC2 instances.

## Usage
```bash

git clone https://github.com/rahul-marchand/KernelCompileScripts
cd KernelCompileScripts
sudo chmod +x *.sh

./initialSetup.sh <kernel_version>    # e.g., ./initialSetup.sh 4.4.1
./updateConfig.sh                     # Smart config update
./finalSetup.sh <kernel_version>      # Compile and install

```
