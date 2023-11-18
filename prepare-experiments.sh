#!/bin/bash

# ----
# Preparation
# load github project over ssh to vm and check that all .sh files are executable

# Install required system packages:
sudo apt-get update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients qemu-utils genisoimage virtinst -y

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
#sudo qemu-img info /var/lib/libvirt/images/kvm-vm/kvm-vm.qcow2
#sudo qemu-img info /var/lib/libvirt/images/qemu-vm/qemu-vm.qcow2

# -----
# Cloud-Init Configuration

# Create meta-data:
cat >meta-data <<EOF
local-hostname: ccex1vm2
EOF

# Read public key into environment variable:
user=$(whoami) && host=$(hostname)
ssh-keygen -t rsa -C "${user}@${host}" -f ~/.ssh/id_rsa -N ""
PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

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
sudo virt-install --connect qemu:///system --virt-type kvm --name kvm-vm --ram 4096 --vcpus=4 --os-variant ubuntu22.04 --disk path=/var/lib/libvirt/images/kvm-vm/kvm-vm.qcow2,format=qcow2 --disk /var/lib/libvirt/images/kvm-vm/kvm-vm-cidata.iso,device=cdrom --import --network network=default --noautoconsole

#QEMU
sudo virt-install --connect qemu:///system --virt-type qemu --name qemu-vm --ram 4096 --vcpus=4 --os-variant ubuntu22.04 --disk path=/var/lib/libvirt/images/qemu-vm/qemu-vm.qcow2,format=qcow2 --disk /var/lib/libvirt/images/qemu-vm/qemu-vm-cidata.iso,device=cdrom --import --network network=default --noautoconsole

# Make sure the virtual machine is running:
#sudo virsh list

# give the initilization of the vms some time
sleep 20s

# Get the IP address:
#sudo virsh domifaddr kvm-vm
kvmVmIp=$(sudo virsh domifaddr kvm-vm | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | xargs)

#sudo virsh domifaddr qemu-vm
qemuVmIp=$(sudo virsh domifaddr qemu-vm | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | xargs)

# Connect to the instance by the public key:
# ssh ubuntu@192.168.122.201

# Copy the benchmark script to each VM
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null benchmark.sh ubuntu@${kvmVmIp}:~/
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null benchmark.sh ubuntu@${qemuVmIp}:~/

# ----
# Install Docker on a Google Cloud virtual machine

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Verify Docker installation:
#docker --version

# ----
# Write a Dockerfile with Ubuntu 22.04 and benchmark
cat > Dockerfile <<EOF
FROM ubuntu:22.04
COPY benchmark.sh /benchmark.sh
RUN apt update -y
RUN apt install sysbench -y
CMD ["./benchmark.sh"]
EOF

#----
# Build the Docker image
sudo docker build -t docker-image .

# Run Docker container in the background
sudo docker run -d --name docker-container docker-image

# Output a message indicating the setup is complete
echo "GCP VM setup complete."