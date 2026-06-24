sysbench cpu --cpu-max-prime=20000 run
sysbench memory run

dd if=/dev/zero of=test bs=1G count=1 oflag=direct
fio --name=test --size=1G --rw=readwrite --bs=4k --iodepth=32

sysbench fileio prepare
sysbench fileio --file-test-mode=rndrw run
sysbench fileio cleanup

stress-ng --cpu 4 --timeout 30s