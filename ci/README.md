buildscripts/ci directory contains scripts used by continuous integration

Make changes in this directory in the master branch and then a workflow at .github/workflows/mirror-ci.yml will create pull requests to mirror the changes to active LTS branches (specified in that yml file).

