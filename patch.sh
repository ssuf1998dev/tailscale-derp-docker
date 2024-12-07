#!/usr/bin/bash

__dirname=$(dirname $(realpath $0))
__tag=$1
declare -a __patch_files=("cmd/derper/cert.go")

pre() {
  if [ -d tailscale ]; then
    while true; do
      read -p "Directory \"tailscale\" exists, overwrite? " yn
      case $yn in
      [Yy]*)
        rm -rf tailscale
        break
        ;;
      [Nn]*)
        echo "[ERROR] Cancelled"
        exit 1
        ;;
      *)
        echo "Please answer yes or no."
        ;;
      esac
    done
  fi

  if [ ! -d patches ]; then
    mkdir patches
  fi
}

checkout() {
  if [[ "$__tag" == "" ]]; then
    echo "[ERROR] Tag is required"
    exit 1
  fi

  if [[ ! $__tag =~ ^v[0-9]+\.[0-9]+ ]]; then
    echo "[ERROR] Wrong tag: $__tag, it should be a semantic version"
    exit 1
  fi

  git init tailscale && pushd tailscale >/dev/null 2>&1
  git config core.sparsecheckout true

  for f in "${__patch_files[@]}"; do
    echo $f >>.git/info/sparse-checkout
  done

  git remote add origin https://github.com/tailscale/tailscale.git

  git pull origin main
  git fetch --tags
  git checkout tags/$__tag -b b_$__tag

  rm -rf .git

  popd >/dev/null 2>&1
}

edit() {
  cp -r tailscale tailscale_old

  pushd tailscale >/dev/null 2>&1
  for f in "${__patch_files[@]}"; do
    $EDITOR $f
  done
  popd >/dev/null 2>&1

  local diffed="$__dirname/patches/$__tag.diff"
  if [ -f $diffed ]; then
    echo "[WARNING] Overwriting existed patch file"
  fi
  diff -ruN tailscale_old tailscale >$diffed

  echo "[SUCCESS] Patch files generated"
}

post() {
  rm -rf tailscale_old
  rm -rf tailscale
}

pre
checkout
edit
post
