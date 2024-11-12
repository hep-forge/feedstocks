#! /usr/bin/bash

wget https://www.roma1.infn.it/~bonvini/hell/downloads/HELL-data.v3.tgz
tar --transform='s,^HELL/,,' -xzvf HELL-data.v3.tgz
wget https://www.roma1.infn.it/~bonvini/hell/downloads/HELL-data-aux.v3.tgz
tar --transform='s,^HELL/,,' -xzvf HELL-data-aux.v3.tgz

make -j$(nproc)

mkdir -p ${PREFIX}/lib
cp -R libhell.a ${PREFIX}/lib
mkdir -p ${PREFIX}/include
cp -R include/* ${PREFIX}/include
mkdir -p share/hell.v3
cp -R data ${PREFIX}/share/hell.v3/
mkdir -p share/bin
cp -R examples/* ${PREFIX}/bin
