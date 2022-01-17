#!/bin/bash

# Ensures that a built version of Offline at the master revision (at master_commit_sha)
# being compared against is available, either from a previous job, or after building.
# exit code 0: master built successfully, or build was restored from cache
# exit code 1: master was not built due to an error
# exit code 2: validation.root was cached for master and does not need to be produced again

NJOBS=16
export REPO=$(echo $REPOSITORY | sed 's|^.*/||')
export WORKING_DIRECTORY_MASTER="$WORKSPACE/master"


mkdir -p $WORKING_DIRECTORY_MASTER
cd "$WORKING_DIRECTORY_MASTER" || exit 1

# note: fetching the PR at the end of this function does not switch to the PR branch, so it's ok here
setup_build_repos "$REPOSITORY" 

# check if we have built libraries for this revision from a previous build
LIB_CACHE_FILE="$WORKSPACE/rev_${MASTER_COMMIT_SHA}_master_lib.tar.gz"
if [ -f "$LIB_CACHE_FILE" ]; then
    echo "Found cached shared libraries from a previous build of master at the revision ${MASTER_COMMIT_SHA}."

    # this will extract the built shared libraries into master/Offline/lib
    tar -xzvf $LIB_CACHE_FILE 2>&1 > /dev/null

    if [ "$?" -eq 0 ] ; then
      echo "Skipping master build step!"

      # check if we have validation.root for this revision from a previous build
      CACHE_FILE="$WORKSPACE/rev_${MASTER_COMMIT_SHA}_master_validation.root"
      if [ -f "$CACHE_FILE" ]; then
          echo "Found a cached validation.root from a previous build of master at the revision ${MASTER_COMMIT_SHA}."
          echo "Skipping master build step!"
          exit 2;
      fi

      exit 0;
    else
      echo "Building master from scratch - something went wrong extracting the archive..."
      rm -f "$WORKING_DIRECTORY_MASTER/$REPO/lib/*"
    fi
fi

cd "$WORKING_DIRECTORY_MASTER/$REPO" || exit 1

# checkout the correct revision
git checkout $MASTER_COMMIT_SHA || exit 1

# dump the rev
echo "[`date`] BUILDING MASTER AT REVISION: $MASTER_COMMIT_SHA"
git log -1

echo "[`date`] printenv"
printenv

echo "[`date`] df -h"
df -h

echo "[`date`] quota"
quota -v

echo "[`date`] PWD"
pwd

echo "[`date`] ls of local dir"
ls -al

echo "[`date`] cpuinfo"
cat /proc/cpuinfo | head -30


# run build in subprocess so parent env stays clean
(
    set --
    echo "["`date`"] setups"
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e
    setup codetools

    # building prof and debug
    setup muse
    muse setup -q $BUILDTYPE # set in Jenkins

    echo "["`date`"] ups"
    ups active

    echo "["`date`"] build"
    muse build -k -j $NJOBS --max-drift=1 --implicit-deps-unchanged 2>&1 | tee scons.log

    RC1=${PIPESTATUS[0]}
    echo "["`date`"] scons return code is $RC1"

    if [ $RC1 -eq 0 ]; then
        echo "[`date`] caching shared libraries at this revision"

        cd "$WORKING_DIRECTORY_MASTER" || exit 1
        tar -zcvf rev_${MASTER_COMMIT_SHA}_master_lib.tar.gz Offline/lib || exit 1

        exit 0;
    fi

    exit $RC1;
)
exit $?
