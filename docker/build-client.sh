PKG_DIR="$HOME/.cfengine/cf-remote/packages"
cf-remote --version master download debian12 client amd64
client_pkg=$(ls -tr "$PKG_DIR" | grep cfengine-nova | grep -v hub | grep debian12 | tail -1)
cp "$PKG_DIR"/"$client_pkg" client.deb

docker stop client || true
docker rm client || true
docker rmi cfengine-client:main || true
docker build --tag cfengine-client:main -f Dockerfile-client .
docker run -h client -d --name client cfengine-client:main sleep infinity
# for developer, we run hub listening on local 5308 HOST port and so bootstrap to HOST IP address, hostname -i on the host, not in the container.
# hack for craig's laptop where I override hostname in $HOME/bin
docker exec client cf-agent -IB $(docker exec hub hostname -i)
docker commit client cfengine-client:main
