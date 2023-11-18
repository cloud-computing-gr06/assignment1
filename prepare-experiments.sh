#!/bin/bash

# ----
# Preparation

# Install required system packages:
sudo apt-get update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients qemu-utils genisoimage virtinst

# Download Ubuntu cloud image:
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O ~/ubuntu-22.04-server.img

# Create directory for base images:
sudo mkdir /var/lib/libvirt/images/base

# Move downloaded image into this folder:
sudo mv ubuntu-22.04-server.img /var/lib/libvirt/images/base/ubuntu-22.04-server.qcow2

# -----
# Virtual machine image

# Create directory for our instance images:
sudo mkdir /var/lib/libvirt/images/kvm-vm
sudo mkdir /var/lib/libvirt/images/qemu-vm

# Create a disk image based on the Ubuntu image:
sudo qemu-img create -f qcow2 -F qcow2 -o backing_file=/var/lib/libvirt/images/base/ubuntu-22.04-server.qcow2 /var/lib/libvirt/images/kvm-vm/kvm-vm.qcow2
sudo qemu-img create -f qcow2 -F qcow2 -o backing_file=/var/lib/libvirt/images/base/ubuntu-22.04-server.qcow2 /var/lib/libvirt/images/qemu-vm/qemu-vm.qcow2

# Verify that image:
sudo qemu-img info /var/lib/libvirt/images/kvm-vm/kvm-vm.qcow2
sudo qemu-img info /var/lib/libvirt/images/qemu-vm/qemu-vm.qcow2

# -----
# Cloud-Init Configuration

# Create meta-data:
cat >meta-data <<EOF
local-hostname: ccex1vm2
EOF

# Read public key into environment variable:
user=$(whoami) && host=$(hostname)
ssh-keygen -t rsa -C "${user}@${host}" -f ~/.ssh/id_rsa -N ""
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
EOF

# Create a disk to attach with Cloud-Init configuration:
sudo genisoimage  -output /var/lib/libvirt/images/kvm-vm/kvm-vm-cidata.iso -volid cidata -joliet -rock user-data meta-data
sudo genisoimage  -output /var/lib/libvirt/images/qemu-vm/qemu-vm-cidata.iso -volid cidata -joliet -rock user-data meta-data

# ----
# Launch virtual machine

#KVM
sudo virt-install --connect qemu:///system --virt-type kvm --name kvm-vm --ram 1024 --vcpus=4 --os-type linux --os-variant ubuntu22.04 --disk path=/var/lib/libvirt/images/kvm-vm/kvm-vm.qcow2,format=qcow2 --disk /var/lib/libvirt/images/kvm-vm/kvm-vm-cidata.iso,device=cdrom --import --network network=default --noautoconsole

#QEMU
sudo virt-install --connect qemu:///system --virt-type qemu --name qemu-vm --ram 1024 --vcpus=4 --os-type linux --os-variant ubuntu22.04 --disk path=/var/lib/libvirt/images/qemu-vm/qemu-vm.qcow2,format=qcow2 --disk /var/lib/libvirt/images/qemu-vm/qemu-vm-cidata.iso,device=cdrom --import --network network=default --noautoconsole

# Make sure the virtual machine is running:
sudo virsh list

# Get the IP address:
sudo virsh domifaddr kvm-vm
sudo virsh domifaddr qemu-vm

# Connect to the instance by the public key:
# ssh ubuntu@192.168.122.201

# ----
# Install Docker on a Google Cloud virtual machine

sudo apt update
sudo apt-get install docker.io

# Verify Docker installation:
docker --version

# ----
# Write a Dockerfile with Ubuntu 22.04 and benchmark
cat <<EOF > Dockerfile
FROM ubuntu:22.04
COPY benchmark.sh /benchmark.sh
RUN chmod +x /benchmark.sh
CMD ["/benchmark.sh"]
EOF

----
# Build the Docker image
sudo docker build -t docker-image .

# Run Docker container in the background
sudo docker run -d --name docker-container docker-image

# Copy the benchmark script to each VM
sudo scp -i ~/.ssh/id_rsa benchmark.sh kvm-vm@<VM_IP>:/home/kvm-vm/benchmark.sh
sudo scp -i ~/.ssh/id_rsa benchmark.sh qemu-vm@<VM_IP>:/home/qemu-vm/benchmark.sh

# Start the VMs
sudo virsh start kvm-vm
sudo virsh start qemu-vm

# Output a message indicating the setup is complete
echo "GCP VM setup complete."