
# howto
# ------------
# 1. upload all .sh files to gcloud vm
# 2. execute prepare-experiments.sh
# 3. execute execute-experiments.sh -> adds itself to cron

Hostname=$(hostname)
# manually change value
Instanz="n1"


# create csv files and add headers
# [n1|n2|c3]-[native|docker|kvm|qemu]-results.csv
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

# run benchmarks
# manually change values
if [ ! -z ${first+x} ]
then
    # add cron rule to execute this file every 30 min
    echo "0,30 * * * * /home/florian/./execute-experiments.sh" | crontab -
else
    ./benchmark.sh >> ${Instanz}-native-results.csv

    sudo docker start 94d6bf033726
    sleep 250s

    ssh ubuntu@192.168.122.232 "/home/ubuntu/./benchmark.sh" >> ${Instanz}-kvm-results.csv

    ssh ubuntu@192.168.122.48 "/home/ubuntu/./benchmark.sh" >> ${Instanz}-qemu-results.csv
fi