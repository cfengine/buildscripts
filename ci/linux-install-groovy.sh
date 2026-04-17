#!/usr/bin/env bash
groovy_version=5.0.3
groovy_zip="apache-groovy-binary-$groovy_version.zip"
cd /opt
rm -rf apache-groovy-binary*zip
wget https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips/"$groovy_zip"
echo "9d711dcb1dea94df9119558365beb6ac2909a22e30b58ae31de8bcb0dcf33698" "$groovy_zip" > "$groovy_zip".sha256
sha256sum -c "$groovy_zip".sha256
unzip -o "$groovy_zip"
ln -sf /opt/groovy-"$groovy_version"/bin/groovy /usr/bin/
echo "export JAVA_HOME=/usr" >> /etc/profile
source /etc/profile
groovy -v
