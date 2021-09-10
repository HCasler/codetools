#!/bin/bash

# Restores the cached build for the PR version being tested
# return code 0: success
# return code 1: error
# return code 2: merge error

NJOBS=16
export REPO=$(echo $REPOSITORY | sed 's|^.*/||')
export WORKING_DIRECTORY_PR="$WORKSPACE/pr"

rm -rf $WORKING_DIRECTORY_PR
mkdir -p $WORKING_DIRECTORY_PR
cd "$WORKING_DIRECTORY_PR" || exit 1

setup_offline "$REPOSITORY"

# switch to Offline and merge in the PR branch at the required master rev
cd "$WORKING_DIRECTORY_PR/$REPO" || exit 1
offline_domerge || exit 2

# back to working directory
cd "$WORKING_DIRECTORY_PR" || exit 1

# check if we have built libraries for this revision from the PR buildtest
LIB_CACHE_FILE="$WORKSPACE/rev_${COMMIT_SHA}_pr_lib.tar.gz"
if [ -f "$LIB_CACHE_FILE" ]; then
    echo "Found cached shared libraries for the PR version."

    # this will extract the built shared libraries into pr/Offline/lib
    tar -xzvf $LIB_CACHE_FILE 2>&1 > $WORKSPACE/pr_build_unzip.log || exit 1;

    echo "Build restored successfully."
else
    echo "Failed to find PR lib cache file ${LIB_CACHE_FILE}"
    exit 1
fi

exit 0;