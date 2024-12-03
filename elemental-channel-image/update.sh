#!/bin/bash

base_url=$1

for arch in x86_64 aarch64; do
 updateinfo=`curl -L -s -o - $base_url/$arch/product/repodata/repomd.xml | sed -n 's,.* href="repodata/\(.*-updateinfo.xml.zst\)".*,\1,p'`
 curl -L -s -o - $base_url/$arch/product/repodata/$updateinfo | zstdcat - > $arch.updateinfo.xml
done
