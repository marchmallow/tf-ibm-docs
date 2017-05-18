#!/bin/bash

# Pulls IBM Terraform documentation from the IBM fork of terraform:
# https://github.com/IBM-Bluemix/terraform - gets the relevant IBM Cloud
# provider documentation from the repo, and builds a new static site from it
# @Author: Chris Kelner
# Copyright (c) 2017 IBM under MIT License

set -ex
PARENT_DIR=$(pwd)

# Array of iternal releases on https://github.ibm.com/blueprint/bluemix-terraform-provider-dev
INTERNAL_RELEASES=( \
  "ibmcloud-v0.1-beta" \
  "ibmcloud-v0.2-beta" \
  "ibmcloud-v0.3-beta" \
  "tf-0.9.3-bluemix-api-key" \
)
INTERNAL_REPO="https://github.ibm.com/blueprint/bluemix-terraform-provider-dev"

# Array of external releases on https://github.com/IBM-Bluemix/terraform/releases
EXTERNAL_RELEASES=( \
  "tf-v0.9.3-ibm-provider-v0.1" \
  #"tf-v0.9.3-ibm-k8s-v0.1" \
  "tf-v0.9.3-ibm-provider-v0.2" \
  "tf-v0.9.3-ibm-provider-v0.2.1" \
)
EXTERNAL_REPO="https://github.com/IBM-Bluemix/terraform"

# Adds arbitrary material to index
function addtoindex() {
  # TODO: Kelner - this can be fraught with failure if the text changes, and
  # will fail to inject the extra content
  sed '/Use the navigation menu on the left to read about the available resources./r./_inject_developing-locally.md' index.html.markdown > tmp
  # TODO: Kelner - cleanup hax, language in old docs is different... see above
  sed '/Use the navigation to the left to read about the available resources./r./_inject_developing-locally.md' index.html.markdown > tmp
  mv tmp index.html.markdown
}

# Expects two arguements:
# $1 is the release tag as specified in git, should come from INTERNAL_RELEASES
# or EXTERNAL_RELEASES
# $2 is the git repo to target, should either be INTERNAL_REPO or EXTERNAL_REPO
function getdocs() {
  if [ ! -d "./source/$1" ]; then
    mkdir ./source/$1
  fi
  if [ ! -d "./terraform" ]; then
    mkdir ./terraform
  fi
  if [ ! -d "./terraform/$1" ]; then
    # clone IBM terraform
    git clone --branch $1 $2 --depth=1 ./terraform/$1
    cd ./terraform/$1
  else
    cd ./terraform/$1
    git pull
  fi
  cp -R website/source/docs/providers/ibmcloud/* ../../source/$1
  cd ../../source/$1
  # inject contents into index
  addtoindex
  cd $PARENT_DIR
}

function cleanuprelease() {
  cd $PARENT_DIR
  if [ -d "./source/$1" ]; then
    rm -rf ./source/$1
  fi
  # TODO: Maybe remove... would rather leave in place and pull if there...
  #if [ -d "./terraform" ]; then
    # I don't like using `-f` but it is necessary in this case
    # otherwise it will prompt the user for:
    # override r--r--r-- for ./terraform/ibmcloud-v0.1-beta/.git/objects/pack/pack-425f29ccef3ed86df8c2e92b655158da0cefd440.idx?
    # for every .git file
    #rm -rf ./terraform
  #fi
  cd $PARENT_DIR
}

function preclean() {
  if [ -d "./build" ]; then
    rm -rf ./build
  fi
  if [ -d "./docs" ]; then
    rm -rf ./docs
  fi
  cleanup
  cleanindex
}

function cleanup() {
  for release in "${INTERNAL_RELEASES[@]}"; do
    cleanuprelease $release
  done
  for release in "${EXTERNAL_RELEASES[@]}"; do
    cleanuprelease $release
  done
  cleanindex
}

function cleanindex() {
  sed '/<!-- REPLACEME -->/q' source/index.html.md
}

function buildversionlist() {
  echo "## Internal Schematic Releases" >> source/index.html.md
  for release in "${INTERNAL_RELEASES[@]}"; do
    echo "- [$release]($release)" >> source/index.html.md
  done
  echo "## Publics Releases" >> source/index.html.md
  for release in "${EXTERNAL_RELEASES[@]}"; do
    echo "- [$release]($release)" >> source/index.html.md
  done
}

# ensure clean start
preclean

# pull all releases from IBM GitHub
for release in "${INTERNAL_RELEASES[@]}"; do
  getdocs $release $INTERNAL_REPO
done

# pull all releases from IBM GitHub
for release in "${EXTERNAL_RELEASES[@]}"; do
  getdocs $release $EXTERNAL_REPO
done

# put all version in index
buildversionlist

# build with middleman
bundle install
bundle exec middleman build --clean --verbose

cleanup

exit 0
