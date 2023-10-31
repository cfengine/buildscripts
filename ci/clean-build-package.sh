#!/usr/bin/env bash
set -ex
# clean up docker stuff
name=cfengine-build-package
# TODO: a softer clean might get into the container and run ./buildscripts/build-scripts/clean-buildmachine
if docker ps | grep $name; then
  docker stop $name
fi
if docker ps -a | grep $name; then
  docker rm $name
fi
if docker images | grep $name; then
  docker rmi -f $name
fi
