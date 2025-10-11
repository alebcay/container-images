#!/bin/sh

registry="${1}"
workdir="${2}"

cd "${workdir}" || exit

name="$(jq --raw-output '.name' < metadata.json)"
version="$(jq --raw-output '.version' < metadata.json)"
strategy="$(jq --raw-output '.strategy' < metadata.json)"
context="."
containerfile="./Containerfile"

if [ "${strategy}" = "remote" ]; then
    url="$(jq --raw-output '.repo.url' < metadata.json)"
    commit="$(jq --raw-output '.repo.commit' < metadata.json)"
    context="$(jq --raw-output '.repo.context' < metadata.json)"
    containerfile="$(jq --raw-output '.repo.containerfile' < metadata.json)"
    tempd="$(mktemp -d)"
    cd "${tempd}" || exit
    git clone "${url}" .
    git checkout "${commit}"
fi

buildah bud --file "${containerfile}" --format oci --tag "${registry}/${name}:${version}" "${context}"
