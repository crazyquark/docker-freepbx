#!/bin/bash

arch=(x86_64 armv7l)
for tag in "${arch[@]}"
do
    docker pull crazyquark/freepbx:15-${tag}
done

docker manifest create crazyquark/freepbx:15 "${arch[@]/#/crazyquark/freepbx:15-}"
docker manifest push --purge crazyquark/freepbx:15
