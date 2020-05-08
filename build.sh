#!/bin/bash
TAG=$(uname -m)
docker buildx build $1 --push -t crazyquark/freepbx:15-$TAG .
