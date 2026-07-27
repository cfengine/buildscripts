buildah images | grep buildhost | awk '{print $3}' | xargs buildah rmi
