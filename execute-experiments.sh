
# howto
# ------------
# 1. upload all .sh files to gcloud vm
# 2. manually change Instanz
# 3. execute prepare-experiments.sh
# 4. execute execute-experiments.sh -> adds itself to cron

Hostname=$(hostname)
# manually change value
Instanz="n1"


# create csv files and add headers
# [n1|n2|c3]-[native|docker|kvm|qemu]-results.csv
# check if file exists and if not create file and add csv header
if [ ! -e ${Instanz}-native-results.csv ] 
then 
    touch ${Instanz}-native-results.csv
    echo "time,cpu,mem,diskRand,diskSeq" > ${Instanz}-native-results.csv
    first="0"
fi

if [ ! -e ${Instanz}-docker-results.csv ] 
then 
    touch ${Instanz}-docker-results.csv
    echo "time,cpu,mem,diskRand,diskSeq" > ${Instanz}-docker-results.csv
fi

if [ ! -e ${Instanz}-kvm-results.csv ] 
then 
    touch ${Instanz}-kvm-results.csv
    echo "time,cpu,mem,diskRand,diskSeq" > ${Instanz}-kvm-results.csv
fi

if [ ! -e ${Instanz}-qemu-results.csv ] 
then 
    touch ${Instanz}-qemu-results.csv
    echo "time,cpu,mem,diskRand,diskSeq" > ${Instanz}-qemu-results.csv
fi



# on first execution of the script add cron job othervise run benchmarks
if [ ! -z ${first+x} ]
then
    # add cron rule to execute this file every 30 min
    echo "0,30 * * * * /home/florian/./execute-experiments.sh" | crontab -
else
    # get docker-id of only container
    Docker_ID=$(sudo docker ps -aq)

    # get ip address for kvm-vm
    sudo virsh domifaddr kvm-vm | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | xargs > tmp.txt
    kvmVmIp=$(cat tmp.txt)
    >tmp.txt

    # get ip address for qemu-vm
    sudo virsh domifaddr qemu-vm | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | xargs > tmp.txt
    qemuVmIp=$(cat tmp.txt)

    # run benchmark nativ and add result to csv
    ./benchmark.sh >> ${Instanz}-native-results.csv

    # run benchmark in docker container and add result to csv
    sudo docker start -a ${Docker_ID} >> ${Instanz}-docker-results.csv

    # run benchmark over ssh in kvm-vm and add result to csv
    ssh ubuntu@${kvmVmIp} "/home/ubuntu/./benchmark.sh" >> ${Instanz}-kvm-results.csv

    # run benchmark over ssh in qemu-vm and add result to csv
    ssh ubuntu@${qemuVmIp} "/home/ubuntu/./benchmark.sh" >> ${Instanz}-qemu-results.csv
fi