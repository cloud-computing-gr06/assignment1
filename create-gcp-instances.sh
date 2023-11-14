
# exercise 1
# submission from:
# florian maximilian henrik hoffmann, 490830

#=============================================

# generate ssh key pair
# ---------------------
# get username and hostname as variables
# -t rsa -> specify that we want an rsa type key
# -C "<username>" -> use <username@host> for key generation
# -f ~/.ssh/id_rsa -> specify name of output file
# -N "" -> we want no passwort protection for the privat key
user=$(whoami) && host=$(hostname)
ssh-keygen -t rsa -C "${user}@${host}" -f ~/.ssh/id_rsa -N ""


# Prepare a modified copy of the public key
# ---------------------
# gcloud wants format -> username:public_ssh-key
# first write username: to tmp file and than append content of public ssh-key
echo -n "${user}:" > prepKey.txt && cat /home/${user}/.ssh/id_rsa.pub >> prepKey.txt


# Upload the public key into your project metadata
# ---------------------
# upload prepared file with public ssh-key in right format
# delete tmp file
gcloud compute project-info add-metadata --metadata-from-file=ssh-keys=prepKey.txt
rm prepKey.txt

# additionally rename ssh-key files to google_compute_engine and google_compute_engine.pub for gcloud to accept it
# gcloud cli only accepts ssh-key if it has this name
mv ~/.ssh/id_rsa ~/.ssh/google_compute_engine && mv ~/.ssh/id_rsa.pub ~/.ssh/google_compute_engine.pub


# Create a firewall rule allowing incoming ICMP and SSH traffic for vms with tag 'cc'
# ---------------------
# default source-range 0.0.0.0\0 (all), default direction ingress
# ...create vm-cc-allow-icmp-ssh -> name rule vm-cc-allow-icmp-ssh
# --action=ALLOW -> we want to allow something
# --rules tcp:22,icmp -> allow icmp traffic and tcp for port 22 for ssh
# --target-tags cc -> add tag to rule
# (incoming ssh and icmp already allowed by default: default-allow-ssh, default-allow-icmp)
gcloud compute firewall-rules create vm-cc-allow-icmp-ssh --action=ALLOW --rules tcp:22,icmp --target-tags cc

# Launch three gcp instances, each with different maschine-type. This should happen in a loop.
# ---------------------
# set variable arrays for loop
# instance n1-standard-4 in Frankfurt(europe-west3-a) / n2-standard-4 in Berlin(europe-west10-a)
# c3-standard-4 in Eemshaven, NL(europe-west4-a)
zones=("europe-west3-a" "europe-west10-a" "europe-west4-a") && \
machines=("n1-standard-4" "n2-standard-4" "c3-standard-4") && \
names=("ccex1vm1" "ccex1vm2" "ccex1vm3")

# Create vm with wanted requirements -> example for one vm
# --image -> select provided image ubuntu-2204
# --imige-project -> select project of image
# --tags cc -> add tag cc to vm
# --enable-nested-virtualization -> enable to run vms inside of other vms
: ' --multiline comment--

gcloud compute instances create ccex1vm1 --image=ubuntu-2204-jammy-v20231030 --image-project=ubuntu-os-cloud \ 
--machine-type=n1-standard-4 --zone=europe-west3-a --tags cc --enable-nested-virtualization
'

# Resize boot-disk to 100gb -> example for one vm
# --size -> size we want in gb (needs to be greater than initial size of 10gb)
: ' --multiline comment--

gcloud compute disks resize ccex1vm1 --size 100 --zone=europe-west3-a
'


# final loop with vm creations and resize of boot disks
for i in `seq 0 2`; do \
gcloud compute instances create ${names[$i]} --image=ubuntu-2204-jammy-v20231030 --image-project=ubuntu-os-cloud \
--machine-type=${machines[$i]} --zone=${zones[$i]} --tags cc --enable-nested-virtualization  && \
gcloud compute disks resize ${names[$i]} --size 100 --zone=${zones[$i]} \
; done

# without line-break
#for i in `seq 0 2`; do gcloud compute instances create ${names[$i]} --image=ubuntu-2204-jammy-v20231030 --image-project=ubuntu-os-cloud --machine-type=${machines[$i]} --zone=${zones[$i]} --tags cc --enable-nested-virtualization  && gcloud compute disks resize ${names[$i]} --size 100 --zone=${zones[$i]}; done



