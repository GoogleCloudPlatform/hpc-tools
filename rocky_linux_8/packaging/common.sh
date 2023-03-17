#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export PKGNAME="google-hpc-compute"
export VERSION=${VERSION:-"20230224.00"}

function exit_error() {
  echo "build failed: $0:$1 \"$BASH_COMMAND\" returned $?"
  exit 1
}

trap 'exit_error $LINENO' ERR

function git_checkout() {
  # Checks out a repo at a specified commit or ref into a specified directory.

  BASE_REPO="$1"
  REPO="$2"
  PULL_REF="$3"

  # pull the repository from github - start
  mkdir -p $REPO
  cd $REPO
  git init

  # fetch only the branch that we want to build
  git_command="git fetch https://github.com/${BASE_REPO}/${REPO}.git ${PULL_REF:-"master"}:packaging"
  echo "Running ${git_command}"
  $git_command

  git checkout packaging
}

function try_command() {
  n=0
  while ! "$@"; do
    echo "attempt $n to run $@"
    if [[ n -gt 3 ]]; then
      return 1
    fi
    ((n++))
    sleep 5
  done
}
