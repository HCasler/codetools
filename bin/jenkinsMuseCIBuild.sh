#!/bin/bash
#
# expects in the environment:
# label=7
# GIT_BRANCH=origin/master (or other branch)
#

initialize() {
  echo "[$(date)] GIT_BRANCH=$GIT_BRANCH"
  echo "[$(date)] printenv"
  printenv
  echo "[$(date)] df -h"
  df -h
  echo "[$(date)] quota"
  quota -v
  echo "[$(date)] PWD"
  pwd
  echo "[$(date)] ls of local dir"
  ls -al
  echo "[$(date)] cpuinfo"
  cat /proc/cpuinfo | head -30

  local ARCH=$( cat /proc/cpuinfo  | grep vendor_id | \
      tail -1 | awk '{print $NF}')
  local NPROC=$( cat /proc/cpuinfo  | grep processor | \
      tail -1 | awk '{print $NF}')
  echo "[$(date)] architecture $ARCH"
  echo "[$(date)] number of processors $NPROC"

  mkdir -p copyBack

  return 0
}

#
# checkout the main repo, branch $BRANCH
# set HASH for this commit
#
getCode() {

    echo "[$(date)] clone"
  # pull the main repo
    if ! git clone https://github.com/Mu2e/Offline ; then
	echo "[$(date)] failed to clone"
	return 1
    fi

    cd Offline

    # set the remote 
    echo "[$(date)] git rename remote"
    if ! git remote rename origin mu2e ; then
	echo "[$(date)]  could not rename remote"
	cd ..
	return 2
    fi

    # define this potential build
    if ! git checkout $BRANCH ; then
	echo "[$(date)]  could not checkout branch $BRANCH"
	cd ..
	return 2
    fi

    export HASH=$( git rev-parse HEAD | cut -c 1-8 )
    if [ -z "$HASH" ] ; then
	echo "[$(date)] could not find hash"
	cd ..
	return 3
    fi
#    local DATE=$( git show $HASH | grep Date: | head -1 | \
#        awk '{print $2" "$3" "$4" "$5" "}' )
#    local DATESTR=$( date -d "$DATE" +%Y_%m_%d_%H_%M)
#    if [[ -z "$DATE" || -z "$DATESTR" ]] ; then
#	echo "[$(date)][$BRANCH] could not parse branch date"
#	cd $BUILDTOP
#	return 4
#    fi
#    local BUILD=$DATESTR_$HASH

    cd ..
    echo "[$(date)] returning from getCode, pwd=$PWD"
    return 0

}


checkExists() {
    
    # see if this hash is already built
    # eventually may need to check this platform specifically
    # when there are multiple platforms
    local TDIR=$BASECDIR/$BRANCH/$HASH/Offline
    if [ -d $TDIR ]; then
	echo "[$(date)][$BRANCH] is up to date at build $BUILD"
	return 1
    fi

    return 0

}

#
# buildBranch with BRANCH=branchName
# cleanup Offline, checkout this branch, see if this hash
# has already has been put on cvmfs, if not, build it and make a tarball
# defining this function with "()" causes it to run in a subshell
# to allow multiple setups in one job
#
buildBranch() {

    echo "[$(date)] start build for hash $HASH with BUILD=$BUILD"

    muse setup -q $BUILD
    RC=$?
    if [ $RC -ne 0 ]; then
	echo "[$(date)] failed to run muse setup"
	return 1
    fi

    muse status
    
    #local SHORT=$MUSE_BUILD_BASE/Offline/lib/libmu2e_Validation_root.so
    #muse build -j 20 --mu2eCompactPrint  $SHORT >& build.log
    muse build -j 20 --mu2eCompactPrint  >& build.log
    RC=$?
    if [ $RC -ne 0 ]; then
	echo "[$(date)] failed to run muse build"
	cat build.log
	return 8
    fi
    
    echo "[$(date)] start deps"
    muse build DEPS
    echo "[$(date)] start gdml"
    muse build GDML
    echo "[$(date)] start git packing"
    muse build GITPACK
    echo "[$(date)] start rm of build temp areas"
    muse build RMSO

    # save the log file
    mv build.log $MUSE_BUILD_BASE/Offline/gen/txt

    return 0
}

tarball() {

    echo "[$(date)] start tarball"

    local FDIR=$BRANCH/$HASH
    local TBALL=copyBack/${BRANCH}+${HASH}.tgz
    mkdir -p $FDIR
    ln -s $PWD/Offline $FDIR/Offline
    ln -s $PWD/build $FDIR/build
    
    if ! tar -czhf $TBALL $BRANCH ; then
	echo "[$(date)] failed to run tar"
	return 1
    fi

    return 0

}

# set a modern git, initial paths
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
# needs to be built
setup muse

export BUILDTOP=$PWD
export BASECDIR=/cvmfs/mu2e-development.opensciencegrid.org/museCIBuild
export LABEL=$label

# print info, check dirs
initialize

# this script is run for one branch
export BRANCH=$( echo $GIT_BRANCH | awk -F/ '{print $NF}' )

# clone and checkout BRANCH, set HASH
getCode
RC=$?
[ $RC -ne 0 ] && exit $RC

# check if this is already built
# I'm not sure why, but I did this in previous CI
checkExists
RC=$?
[ $RC -ne 0 ] && exit $RC

for BUILD in prof debug
do
    # in parens so that setup does not persist
    ( buildBranch )
    RC=$?
    [ $RC -ne 0 ] && exit $RC
done

tarball
RC=$?
[ $RC -ne 0 ] && exit $RC


exit 0
