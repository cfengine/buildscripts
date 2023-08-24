#!/usr/bin/env bash
set -ex
# clean up docker stuff
name=cfengine-build-package
# TODO: a softer clean might get into the container and run ./buildscripts/build-scripts/clean-buildmachine
docker stop $name
docker rm -f $name
docker rmi -f $name
