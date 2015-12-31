#!/bin/bash
#
#
# Ray Culbertson
#

usage()
{
    echo "
 Pull an Offline release build from Jenkins build machine
 \$1 = git release tag, like v5_2_1
 \$2,\$3 = select subsets.  If SLF5 then do SLF5, prof and debug.  
   If debug then do SLF5 and 6, for debug. If SLF5 debug then
   only do SLF5 debug.

  Should be run in the directory where the verison listing
  will appear (cd /cvmfs/mu2e.opensciencegrid.org/Offline).

"
}


export TAG=$1

if [ "$TAG" == "" ]; then
  usage
  exit 1
fi

OSLIST=""
BBLIST=""
shift
for AA in $*
do
  [ $AA == "SLF5" ] && OSLIST="$OSLIST $AA"
  [ $AA == "SLF6" ] && OSLIST="$OSLIST $AA"
  [ $AA == "prof"  ] && BBLIST="$BBLIST $AA"
  [ $AA == "debug" ] && BBLIST="$BBLIST $AA"
done
[ -z "$OSLIST" ] && OSLIST="SLF5 SLF6"
[ -z "$BBLIST" ] && BBLIST="prof debug"
echo OSLIST=$OSLIST
echo BBLIST=$BBLIST

export BDIR=$PWD

for OS in $OSLIST
do
  for TYPE in $BBLIST
  do
    cd $BDIR
    echo "Filling $PWD/${TAG}/${OS}/${TYPE}"
    mkdir -p ${TAG}/${OS}/${TYPE}
    cd ${TAG}/${OS}/${TYPE}
    export TBALL=Offline_${TAG}_${OS}_${TYPE}.tgz
    export URL="https://buildmaster.fnal.gov/view/mu2e/job/mu2e-offline-build/BUILDTYPE=${TYPE},label=${OS}/lastSuccessfulBuild/artifact/mu2e_tarballs/$TBALL"
    wget $URL
    RC=$?
    if [ $RC -ne 0 ];then
      echo "ERROR - wget failed on $TBALL"
      echo "skipping this build"
      break
    fi
    tar -xzf $TBALL
    rm -f $TBALL
    SIZE=`du -ms Offline | awk '{print $1}'`
    echo Unrolled $SIZE MB
    echo ""

    wget -O build.log https://buildmaster.fnal.gov/view/mu2e/job/mu2e-offline-build/BUILDTYPE=${TYPE},label=${OS}/lastBuild/consoleText

  done
done

exit


# copy the artifacts from the last succcessful build of a Jenkins project

usage()
{
    echo "$(basename ${0}) <project> [build type] [OS]"
    echo "    NOTE: this script pulls the last successful build"
    echo "    The Jenkins project name (e.g., geant4-release-build) is required"
    echo "    if build type is not specified, both debug and prof will be copied"
    echo "    if OS is not specified, the script will look for SLF5, SLF6, and OS_X"
}

project="${1}"

if [ -z ${project} ]
then
  echo "ERROR: please specify at least the release url"
  usage
  exit 1
fi

build_type="${2}"
build_os="${3}"

case ${build_type} in
  debug)  
    build_array=(${build_type}) ;;
  opt)  
    build_array=(${build_type}) ;;
  prof)
    build_array=(${build_type}) ;;
  none)
    build_array=(${build_type}) ;;
  *)
    echo "will copy debug and prof artifacts"
    build_array=(debug prof)
esac

case ${build_os} in
  SLF5)  
    os_array=(${build_os}) ;;
  SLF6)  
    os_array=(${build_os}) ;;
  OS_X)
    os_array=(${build_os}) ;;
  *)
    echo "will copy artifacts for SLF5 SLF6 OS_X"
    os_array=(SLF5 SLF6 OS_X)
esac

for (( i=0; i<${#os_array[@]}; i++ ));
do
  OS=${os_array[$i]}

  for (( j=0; j<${#build_array[@]}; j++ ));
  do
    if [ "${build_array[$j]}" = "none" ]
    then
      btype=""
    else
      btype="BUILDTYPE=${build_array[$j]},"
    fi

    url="https://buildmaster.fnal.gov/job/${project}/${btype}label1=swarm,label2=${OS}/lastSuccessfulBuild/artifact/copyBack/"

    artifacts=(`curl -F "web=@;type=text/html" ${url} \
      | sed -e 's/<\/a>/<\/a>\n/g' \
      | sed -e 's/<a href/\n <a href/g' \
      | grep view | grep -v \/view \
      | sed -e 's/<a href=\"//' \
      | sed -e 's/\">view<\/a>//' \
      | sed -e 's/\/\*view\*\///'`)

    for (( k=0; k<${#artifacts[@]}; k++ ));
    do
      echo "copy ${url}/${artifacts[$k]}"
      curl -O ${url}/${artifacts[$k]}
    done

  done

done

exit 0
