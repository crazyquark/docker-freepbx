#!/bin/bash
docker buildx build $1 --platform linux/amd64,linux/arm/v7 --push -t crazyquark/freepbx:15 .
