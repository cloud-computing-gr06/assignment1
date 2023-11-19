#!/bin/bash

# ----
# Preparation
# load github project over ssh to vm and check that all .sh files are executable
# reference: https://medium.com/@art.vasilyev/use-ubuntu-cloud-image-with-kvm-1f28c19f82f8

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
# #qemu-img is a command line tool that allow you create, convert, and modify disk images offline. In this case, create a disk image.
# #create [--object OBJECTDEF] [-q] [-f FMT] [-b BACKING_FILE [-F BACKING_FMT]] [-u] [-o OPTIONS] FILENAME [SIZE]
# #Create the new disk image FILENAME of size SIZE and format FMT. Depending on the file format, you can add one or more OPTIONS that enable additional features of this format.
# #-f first image format. -F second image format. -o options for the new image.
# #qcow2 format QEMU image format, the most versatile format. Use it to have smaller images (useful if your filesystem does not supports holes, for example on Windows), zlib based compression and support of multiple VM snapshots.
# #backing_file is file name of a base image. The new image starts out as a copy of the base image.
sudo qemu-img create -f qcow2 -F qcow2 -o backing_file=/var/lib/libvirt/images/base/ubuntu-22.04-server.qcow2 /var/lib/libvirt/images/kvm-vm/kvm-vm.qcow2
sudo qemu-img create -f qcow2 -F qcow2 -o backing_file=/var/lib/libvirt/images/base/ubuntu-22.04-server.qcow2 /var/lib/libvirt/images/qemu-vm/qemu-vm.qcow2

# Verify the image:

#sudo qemu-img info /var/lib/libvirt/images/kvm-vm/kvm-vm.qcow2
#sudo qemu-img info /var/lib/libvirt/images/qemu-vm/qemu-vm.qcow2

# -----
# Cloud-Init Configuration

# Create meta-data:
## cat > to create a file.<<EOF is a heredoc that can create a file with multiple lines.
## meta-data is the file name.
## local-hostname: ccex1vm1 is the content of the file. (hostname of the virtual machine.)
## EOF is the end of the heredoc.
cat >meta-data <<EOF
local-hostname: ccex1vm2
EOF

# Read public key into environment variable:
## user is the username of the current user. whoami is a command that returns the username of the current user. Same for host.
## ssh-keygen is a command that generates a new SSH key. -t option specifies the type of key to create. rsa is the key type.
## -C option adds a comment to the key. -f option specifies the filename of the key file. -N option specifies the passphrase of the key file.
## ~/.ssh/id_rsa is the path of the key file.
## PUB_KEY as environment variable that stores the public key. 
user=$(whoami) && host=$(hostname)
ssh-keygen -t rsa -C "${user}@${host}" -f ~/.ssh/id_rsa -N ""
PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

# Create user-data:
## Same as meta-data.
## users is the list of users. - name is the username of the user. ssh_authorized_keys is the list of public keys that can be used to login as the user.
## sudo is the list of commands that the user can run as root without password. groups is the list of groups that the user belongs to. 
## /bin/bash is the shell of the user.
## we put the public key into the user-data file therefore we can login to the virtual machine with the private key.
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
## genisoimage is a command to create an ISO image.
## -output specifies the output file.
## -volid specifies the volume ID of the ISO image. 
## cidata is the volume ID of the ISO image. volume ID used to identify the ISO image.
## -joliet option to generate Joliet directory records in addition to regular iso9660 file names.
## -rock option to generate Rock Ridge directory information in addition to regular iso9660 file names.
## user-data and meta-data are the files to include in the ISO image that we created earlier.
## we need to do these on both kvm-vm and qemu-vm.
sudo genisoimage  -output /var/lib/libvirt/images/kvm-vm/kvm-vm-cidata.iso -volid cidata -joliet -rock user-data meta-data
sudo genisoimage  -output /var/lib/libvirt/images/qemu-vm/qemu-vm-cidata.iso -volid cidata -joliet -rock user-data meta-data

# ----
# Launch virtual machine

#KVM
## --connect is the hypervisor to connect to. qemu:///system is the hypervisor to connect to.
## --virt-type is the virtualization type. kvm is the virtualization type.
## --name is the name of the virtual machine. 
## --ram is the amount of memory in MB. 4096 
## --vcpus is the number of virtual CPUs. 4 
## --os-variant is the OS variant. ubuntu22.04
## --disk is the disk image. path option specifies the path of the disk image. format option specifies the format of the disk image.
## --disk is the cloud-init configuration. device option specifies the device type. cdrom 
## --import to import the disk image.
## --noautoconsole to not automatically connect to the console. Because we are using cloud-init, we don't need to connect to the console.
sudo virt-install --connect qemu:///system --virt-type kvm --name kvm-vm --ram 4096 --vcpus=4 --os-variant ubuntu22.04 --disk path=/var/lib/libvirt/images/kvm-vm/kvm-vm.qcow2,format=qcow2 --disk /var/lib/libvirt/images/kvm-vm/kvm-vm-cidata.iso,device=cdrom --import --network network=default --noautoconsole

#QEMU
# Same as KVM
sudo virt-install --connect qemu:///system --virt-type qemu --name qemu-vm --ram 4096 --vcpus=4 --os-variant ubuntu22.04 --disk path=/var/lib/libvirt/images/qemu-vm/qemu-vm.qcow2,format=qcow2 --disk /var/lib/libvirt/images/qemu-vm/qemu-vm-cidata.iso,device=cdrom --import --network network=default --noautoconsole

# Make sure the virtual machine is running:
# sudo virsh list

# give the initilization of the vms some time
# because of the cloud-init configuration, it takes some time for the virtual machine to boot up.
# if we try to connect to the virtual machine before it is ready, we will get an error.
sleep 20s

# Get the IP address:
## sudo virsh domifaddr kvm-vm will return the IP address of the virtual machine kvm-vm.
## | is a pipe. It lets us use the output of one command as the input of another command. In this case, the output of sudo virsh domifaddr kvm-vm is the input of grep.
## grep -o option to only return the IP address.
## xargs option to remove the trailing newline.
## >tmp.txt to save the IP address to a file.
## cat tmp.txt to read the IP address from the file.
## kvmVmIp is the IP address of the virtual machine.
## rm tmp.txt to remove the file.
sudo virsh domifaddr kvm-vm | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | xargs > tmp.txt
kvmVmIp=$(cat tmp.txt)
>tmp.txt

# sudo virsh domifaddr qemu-vm will return the IP address of the virtual machine qemu-vm.
sudo virsh domifaddr qemu-vm | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | xargs > tmp.txt
qemuVmIp=$(cat tmp.txt)
rm tmp.txt

# Connect to the instance by the public key:
## username@ip is the username and IP address of the virtual machine.
# ssh ubuntu@192.168.122.201

# Copy the benchmark script to each VM:
# scp is a command to copy files over SSH.
# -o StrictHostKeyChecking=no option to disable host key checking. Because we are using cloud-init, the host key will change every time we create a new virtual machine.
# -o UserKnownHostsFile=/dev/null option to disable host key checking. 
# ubuntu@${kvmVmIp}:~/ and ubuntu@${qemuVmIp}:~/ is the destination of the file. We need ~/ to specify the home directory.
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null benchmark.sh ubuntu@${kvmVmIp}:~/
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null benchmark.sh ubuntu@${qemuVmIp}:~/

# ----
# Install Docker on a Google Cloud virtual machine

# Add Docker's official GPG key:
sudo apt-get update
# ca-certificates is a package that lets us install certificates. The certificates are used to verify the authenticity of the packages.
# curl is a command to transfer data. We use curl to download the GPG key.
# gnupg is a package that lets us manage GPG keys. 
sudo apt-get install ca-certificates curl gnupg
# -m option to specify the permission of the directory. 0755 is the permission of the directory. this permission means that the owner can read, write, and execute. the group and others can read and execute.
# -d option to create a directory. etc/apt/keyrings is the directory to create.
sudo install -m 0755 -d /etc/apt/keyrings
# -fsSL option to follow redirects. -o option to specify the output file. /etc/apt/keyrings/docker.gpg is the output file.
# https://download.docker.com/linux/ubuntu/gpg is the URL of the GPG key.

# gpg is a command to manage GPG keys. --dearmor option to convert the GPG key to binary format. -o option to specify the output file. /etc/apt/keyrings/docker.gpg is the output file.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# chmod is a command to change the permission of a file. a+r option to add read permission to all users.
# /etc/apt/keyrings/docker.gpg is the file to change the permission.
# because the default permission of the file is 0600. this permission means that only the owner can read and write, but we want all users to be able to read.
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
## arch is the architecture of the system.
## dpkg is a command to manage packages from debian packages. --print-architecture option to print the architecture of the system. dpkg --print-architecture will return the architecture of the system.
## signed-by option to specify the GPG key. /etc/apt/keyrings/docker.gpg is the GPG key.
## $(. /etc/os-release && echo "$VERSION_CODENAME") is the codename of the operating system.
## /etc/os-release is a file that contains information about the os.
## VERSION_CODENAME is the codename of the operating system.
## /dev/null is a special file that discards all data written to it. We use this file to discard the output of the command. Because we don't want to see the output of the command.
## We update the package list because a new repository is added.
## -y option to automatically answer yes to all questions.
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Verify Docker installation:
#docker --version

# ----
# Write a Dockerfile with Ubuntu 22.04 and benchmark:
# Copy the benchmark script to the Docker container.
# RUN option to run a command. apt-get update to update the package list. -y option to automatically answer yes to all questions. apt-get install sysbench to install sysbench.
# CMD option to specify the command to run when the container starts. ./benchmark.sh is the command to run when the container starts.
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
