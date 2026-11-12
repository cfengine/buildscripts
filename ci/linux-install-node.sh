#!/usr/bin/env bash

node_version=24.22.2

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
echo "2644f0845671e149b8b0705a4fdcca2993995348618dc98c681ba0c7cdf604d2  node-v$node_version-linux-x64-glibc-217.tar.xz" | sudo tee node-v$node_version-linux-x64-glibc-217.tar.xz.sha256
sudo sha256sum --check node-v$node_version-linux-x64-glibc-217.tar.xz.sha256
sudo tar xf node-v$node_version-linux-x64-glibc-217.tar.xz
sudo tee /etc/profile.d/nodejs.sh << EOF
export NODE_HOME=/opt/node-v$node_version-linux-x64-glibc-217
export PATH=\$PATH:\$NODE_HOME/bin
EOF
for tool in node npm npx corepack; do
  sudo update-alternatives --install /usr/bin/$tool $tool /opt/node-v$node_version-linux-x64-glibc-217/bin/$tool 1
  # an older version may already be registered with the same priority, so select the new one explicitly
  sudo update-alternatives --set $tool /opt/node-v$node_version-linux-x64-glibc-217/bin/$tool
done
cd /root

