#!/bin/sh

registry="${1}"
workdir="${2}"

cd "${workdir}" || exit

name="$(jq --raw-output '.name' < metadata.json)"
version="$(jq --raw-output '.version' < metadata.json)"

podman push --compression-format=zstd --compression-level=10 "${registry}/${name}:${version}"
