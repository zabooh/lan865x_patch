#!/bin/bash

## Get LAN9662 Board Support Package
wget http://mscc-ent-open-source.s3-eu-west-1.amazonaws.com/public_root/bsp/mscc-brsdk-source-2024.12.tar.gz
mv mscc-brsdk-source-2024.12.tar.gz ../
cd ../
tar xf mscc-brsdk-source-2024.12.tar.gz

## Build Firmware first time
cd mscc-brsdk-source-2024.12
make BR2_EXTERNAL=./external O=./output/mybuild arm_standalone_defconfig
cd ./output/mybuild

make 

