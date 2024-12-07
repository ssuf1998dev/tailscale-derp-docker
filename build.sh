#!/usr/bin/bash

__tag=$1

if [[ "$__tag" == "" ]]; then
  echo "[ERROR] Tag is required"
  exit 1
fi

if [[ ! $__tag =~ ^v[0-9]+\.[0-9]+ ]]; then
  echo "[ERROR] Wrong tag: $__tag, it should be a semantic version"
  exit 1
fi

git clone -b $__tag --depth=1 https://github.com/tailscale/tailscale.git tailscale

if [ ! -f patches/$__tag.diff ]; then
  echo "[WARNING] No patch file found"
else
  patch -p0 <"patches/$__tag.diff"
fi
