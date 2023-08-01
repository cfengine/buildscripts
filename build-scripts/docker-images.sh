#!/usr/bin/env bash
set -ex
registry=${2:-localhost:5001} # TODO make public cfengine AWS ECR registry :)

cat <<EOF >Dockerfile-ubuntu-20-systemd
FROM ubuntu:20.04
RUN apt-get update && apt-get install -q -y systemd wget sudo
CMD [ "/lib/systemd/systemd" ]
EOF

for name in cfengine-hub cfengine-agent; do
  if [ "$name" = "cfengine-agent" ]; then
    install_type="agent"
  else
    install_type="hub"
  fi
  if docker ps -a | grep $name; then
    docker ps -a | grep $name | awk '{print $1}' | xargs docker stop
    docker ps -a | grep $name | awk '{print $1}' | xargs docker rm
    docker rm $name
  fi
  if docker images | grep $name; then
    docker images | grep $name | awk '{print $3}' | xargs docker rmi --force
  fi
  
  docker build -t $name -f Dockerfile-ubuntu-20-systemd .
  docker run -d --privileged --name $name $name
  docker exec -i $name bash -c "wget https://s3.amazonaws.com/cfengine.packages/quick-install-cfengine-enterprise.sh  && sudo bash ./quick-install-cfengine-enterprise.sh $install_type"
  docker commit $name $name:latest
  docker image tag $name:latest $registry/cfengine/$name:latest
  docker image push $registry/cfengine/$name:latest
  docker stop $name
  docker rm $name
  docker rmi $name
done
