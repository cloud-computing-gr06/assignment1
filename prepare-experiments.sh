#!/bin/bash

# Install required system packages:
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients qemu-utils genisoimage virtinst

# Download Ubuntu cloud image:
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O ~/cloud-image/ubuntu-22.04-server.img

# Create directory for base images:
sudo mkdir /var/lib/libvirt/images/base

# Move downloaded image into this folder:
sudo mv ubuntu-22.04-server.img /var/lib/libvirt/images/base/ubuntu-22.04-server.qcow2

#-----
# Virtual machine image

# Create directory for our instance images:
sudo mkdir /var/lib/libvirt/images/ccex1vm1

# Create a disk image based on the Ubuntu image:
sudo qemu-img create -f qcow2 -F qcow2 -o backing_file=/var/lib/libvirt/images/base/ubuntu-22.04-server.qcow2 /var/lib/libvirt/images/ccex1vm1/ccex1vm1.qcow2

# Verify that image:
sudo qemu-img info /var/lib/libvirt/images/ccex1vm1/ccex1vm1.qcow2

# Current virtual size is 2.2 GB, let’s set it to 4 GB:
sudo qemu-img resize /var/lib/libvirt/images/ccex1vm1/ccex1vm1.qcow2 4G

# Check if resized
sudo qemu-img info /var/lib/libvirt/images/ccex1vm1/ccex1vm1.qcow2

# -----
# Cloud-Init Configuration

# Create meta-data:
cat >meta-data <<EOF
local-hostname: ccex1vm1
EOF

# Read public key into environment variable:
export PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

# Create user-data:
cat >user-data <<EOF
#cloud-config
users:
  - name: ubuntu
    ssh_authorized_keys:
      - $PUB_KEY
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
runcmd:
  - echo "AllowUsers ubuntu" >> /etc/ssh/sshd_config
  - restart ssh
EOF

# Create a disk to attach with Cloud-Init configuration:
sudo genisoimage  -output /var/lib/libvirt/images/ccex1vm1/ccex1vm1-cidata.iso -volid cidata -joliet -rock user-data meta-data

# ----
# Launch virtual machine

sudo virt-install --connect qemu:///system --virt-type kvm --name ubuntu --ram 1024 --vcpus=1 --os-type linux --os-variant ubuntu22.04 --disk path=/var/lib/libvirt/images/ccex1vm1/ccex1vm1.qcow2,format=qcow2 --disk /var/lib/libvirt/images/ccex1vm1/ccex1vm1-cidata.iso,device=cdrom --import --network network=default --noautoconsole

# Make sure the virtual machine is running:
sudo virsh list

# Get the IP address:
sudo virsh domifaddr ubuntu

# Connect to the instance by the public key:
ssh ubuntu@192.168.122.201

# ----
# Install Docker on a Google Cloud virtual machine

sudo apt update
sudo apt-get install docker.io

# Verify Docker installation:
docker --version
docker run hello-world

----
# Write a Dockerfile with Ubuntu 22.04 and benchmark
cat <<EOF > Dockerfile
FROM ubuntu:22.04
COPY benchmark.sh /benchmark.sh
RUN chmod +x /benchmark.sh
CMD ["/benchmark.sh"]
EOF

----
# Build the Docker image
sudo docker build -t benchmark-image .

# Run Docker container in the background
docker run -d --name benchmark-container benchmark-image

# Copy the benchmark script to each VM
sudo scp benchmark.sh user@<VM_IP>:/home/user/benchmark.sh

# Start the VMs
sudo virsh start ubuntu

# Output a message indicating the setup is complete
echo "GCP VM setup complete. You can now SSH into the VMs and run experiments."
