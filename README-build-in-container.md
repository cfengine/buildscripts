Build with ./build-in-container.py

Using ./build-in-container.py --shell you can run the build interactively and debug issues.
Start in the container by running /srv/source/buildscripts/build-in-container-inner.sh

This will copy repository sources that are needed from the read-only /srv location to read-write work area in /home/builder/build.

Continue debugging by running steps in /home/builder/buildscripts/build-scripts/0*.sh
