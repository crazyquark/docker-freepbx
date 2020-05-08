#!/bin/bash
docker buildx build --platform linux/amd64 --platform linux/arm/v7 --push -t crazyquark/freepbx:15 .