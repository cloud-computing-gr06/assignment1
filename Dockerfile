FROM ubuntu:22.04
COPY benchmark.sh /benchmark.sh
RUN apt update -y
RUN apt install sysbench -y
CMD ["./benchmark.sh"]