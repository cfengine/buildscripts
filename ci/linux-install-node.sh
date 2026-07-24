#!/usr/bin/env bash

node_version=20.10.0

npm install compare-versions

node -e "const cv = require('compare-versions'); process.exit(cv.compareVersions('$node_version', process.version));"
result=$?
echo "result: $result"
if [ "$result" != "1" ]; then
  echo "node version is >= $node_version, no install will be performed."
  exit
fi

cd /opt
sudo curl -k -O https://unofficial-builds.nodejs.org/download/release/v$node_version/node-v$node_version-linux-x64-glibc-217.tar.xz
echo "dcfc5dfcdea4d0883bb35a4f2e09bc4745b6e689d88f4ad09d9ccc252024049b  node-v$node_version-linux-x64-glibc-217.tar.xz" | sudo tee node-v$node_version-linux-x64-glibc-217.tar.xz.sha256
sudo sha256sum --check node-v$node_version-linux-x64-glibc-217.tar.xz.sha256
sudo tar xf node-v$node_version-linux-x64-glibc-217.tar.xz
sudo tee /etc/profile.d/nodejs.sh << EOF
export NODE_HOME=/opt/node-v$node_version-linux-x64-glibc-217
export PATH=\$PATH:\$NODE_HOME/bin
EOF
sudo update-alternatives --install /usr/bin/node node /opt/node-v$node_version-linux-x64-glibc-217/bin/node 1
sudo update-alternatives --install /usr/bin/npm npm /opt/node-v$node_version-linux-x64-glibc-217/bin/npm 1
sudo update-alternatives --install /usr/bin/npx npx /opt/node-v$node_version-linux-x64-glibc-217/bin/npx 1
sudo update-alternatives --install /usr/bin/corepack corepack /opt/node-v$node_version-linux-x64-glibc-217/bin/corepack 1
cd /root

