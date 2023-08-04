# clean up docker stuff
name=cfengine-deployment-tests
# TODO: a softer clean might get into the container and run ./buildscripts/build-scripts/clean-buildmachine
docker stop $name
docker rm $name
docker rmi $name
