#!/usr/bin/env bash
set -e
# install jdk "manually"
# depending on os, might want to do something like `apt remove default-jre openjdk-*-jre-*`
cd /opt
wget https://download.java.net/java/GA/jdk21.0.1/415e3f918a1f4062a0074a2794853d0d/12/GPL/openjdk-21.0.1_linux-x64_bin.tar.gz
echo "7e80146b2c3f719bf7f56992eb268ad466f8854d5d6ae11805784608e458343f  openjdk-21.0.1_linux-x64_bin.tar.gz"  | sha256sum --check -
sudo tar xf openjdk-21.0.1_linux-x64_bin.tar.gz
sudo tee /etc/profile.d/jdk.sh << EOF
export JAVA_HOME=/opt/jdk-21.0.1
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
sudo chown -R root:jenkins /opt/jdk-21.0.1
sudo chmod -R g+rx /opt/jdk-21.0.1
if command -v update-alternatives; then
  sudo update-alternatives --install /usr/bin/java java /opt/jdk-21.0.1/bin/java 9999
else
  sudo ln -s /opt/jdk-21.0.1/bin/java /usr/bin/java
fi
cd -
