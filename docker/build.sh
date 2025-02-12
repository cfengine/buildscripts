set -ex
image=cfengine-hub
tag=main
cf-remote --version master download debian12 hub amd64
PKG_DIR="$HOME/.cfengine/cf-remote/packages"
hub_pkg=$(ls -tr "$PKG_DIR" | grep cfengine-nova-hub | grep debian12 | tail -1)
cp "$PKG_DIR"/"$hub_pkg" hub.deb

docker stop hub || true
docker rm hub || true
docker rmi $image:$tag || true

docker build --tag $image:$tag -f Dockerfile-hub .

docker run -h hub -d -p 8443:8443 -p 5308:5308 -p 8080:8080 --name hub $image:$tag sleep infinity
docker ps
# here we need a two-step
# one to make the initial image with `hub` as hostname and configured/setup package
docker exec hub bash -x /post-build-setup.sh
# but then, what if someone wants to change the internal hostname? I don't think this is so important?
# but... if they do, we need to change the certs, just the filenames maybe
# so maybe a utility for `cfe` for `cfe hostname <hostname>` which handles the details
docker exec -it hub bash

# and now... make the final image and publish to hub.docker.com, free25 in a container! :)
docker commit hub cfengine-hub:main

cf-remote --version master download debian12 client amd64
client_pkg=$(ls -tr "$PKG_DIR" | grep cfengine-nova
cp "$PKG_DIR"/"$client_pkg" client.deb

docker stop client || true
docker rm client || true
docker rmi cfengine-client:main || true
docker build --tag cfengine-client:main -f Dockerfile-client .
docker run -h client -d --name client cfengine-client:main sleep infinity
# for developer, we run hub listening on local 5308 HOST port and so bootstrap to HOST IP address, hostname -i on the host, not in the container.
docker exec client cf-agent -IB $(hostname -i)
docker commit client cfengine-client:main
