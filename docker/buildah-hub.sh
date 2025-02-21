set -ex
image=cfengine-hub
tag=main
name=hub

cf-remote --version master download debian12 hub amd64
PKG_DIR="$HOME/.cfengine/cf-remote/packages"
hub_pkg=$(ls -tr "$PKG_DIR" | grep cfengine-nova-hub | grep debian12 | tail -1)
cp "$PKG_DIR"/"$hub_pkg" hub.deb

# prepare the local host
sudo systemctl disable cfengine3
sudo systemctl stop cfengine3
#docker stop hub || true
buildah rm hub || true
#docker rm hub || true
#docker rmi $image:$tag || true
buildah rmi $iamge:$tag || true

# TODO, make optional, use local masterfiles since it is easy to replace in the container
cwd=$(pwd)
rm -rf mpf-build
cd $HOME/cfe/masterfiles
rm -f cfengine-masterfiles*tar.gz
./autogen.sh
make dist
tar xf cfengine-masterfiles*tar.gz
dirname=$(basename cfengine-masterfiles-*.tar.gz .tar.gz)
mv "$dirname" "$cwd"/mpf-build
cd -
#docker build --tag $image:$tag -f Dockerfile-hub .
buildah from docker.io/library/debian:12-slim --name hub
buildah run hub bash -c 'apt update -y && apt upgrade -y'
buildah run hub apt install -y procps python3-minimal ed
buildah copy hub hub.deb /
buildah run hub dpkg --unpack hub.deb
buildah run hub rm -rf /var/cfengine/share/NovaBase/masterfiles
buildah copy hub mpf-build/ /var/cfengine/share/NovaBase/masterfiles/
buildah copy hub def.json /var/cfengine/share/NovaBase/masterfiles/def.json
buildah copy hub post-build-setup.sh /


#docker run -h hub -d -p 8443:8443 -p 5308:5308 -p 8080:8080 --name hub $image:$tag sleep infinity
#docker ps
# here we need a two-step
# one to make the initial image with `hub` as hostname and configured/setup package
#docker exec hub bash -x /post-build-setup.sh
# but then, what if someone wants to change the internal hostname? I don't think this is so important?
# but... if they do, we need to change the certs, just the filenames maybe
# so maybe a utility for `cfe` for `cfe hostname <hostname>` which handles the details
#docker exec -it hub bash

# and now... make the final image and publish to hub.docker.com, free25 in a container! :)
#docker commit hub cfengine-hub:main
buildah config -p 8443 hub
