#!/bin/bash

cd /work/rust-optee-trustzone-sdk/
rm -rf .git
cd optee-qemuv8-3.7.0/
rm -rf .repo
mv linux/arch/arm64/boot/Image /tmp
rm -r linux
mkdir -p linux/arch/arm64/boot/
mv /tmp/Image linux/arch/arm64/boot/

mv out-br/images /tmp
rm -r out-br
mkdir -p out-br/
mv /tmp/images out-br/
mkdir -p /tmp/out
cp out/bin/* /tmp/out
rm -f out/bin/*
mv /tmp/out/* out/bin/


