#!/bin/bash

# e.g. valplot.sh master ceSimReco <commit sha specific to that build>
# Sets up the build in $WORKSPACE/$1 and runs validation according to Production/Validation/$2.fcl
# then makes validation plots, and moves the rootfile back to workspace.
# return code 0: success
# return code 1: error

WORKING_DIRECTORY="$WORKSPACE/$1"
BUILDVER=$1
VALIDATION_JOB=$2
COMMIT_SHA_V=$3

if [ -f "$WORKSPACE/rev_${COMMIT_SHA_V}_${BUILDVER}_validation.root" ]; then
    echo "Found cached validation rootfile for the ${BUILDVER} version at ${COMMIT_SHA_V}."
    exit 0;
fi


(
    set --
    cd "$WORKING_DIRECTORY" || exit 1
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup mu2e

    setup muse
    muse setup

    echo "[$(date)] ($WORKING_DIRECTORY) ${VALIDATION_JOB} (${VALIDATION_EVENTS} events)"
    mu2e -n ${VALIDATION_EVENTS} -c Production/Validation/${VALIDATION_JOB}.fcl 2>&1 | tee "$WORKING_DIRECTORY/${VALIDATION_JOB}.log" 
    RC2=${PIPESTATUS[0]}
    echo "[$(date)] ($WORKING_DIRECTORY) ${VALIDATION_JOB} return code is $RC2"

    if [ "$RC2" -ne 0 ]; then
        echo "[$(date)] ($WORKING_DIRECTORY) error while running validation job - abort"
        append_report_row "${VALIDATION_JOB} (${BUILDVER})" ":x:" "[Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/TBD.log)" # TODO: work out where this goes
        exit 1;
    fi
    # may or may not want this reported every time
    #append_report_row "${VALIDATION_JOB} (${BUILDVER})" ":white_check_mark:" "[Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/TBD.log)" # TODO: work out where this goes

    echo "[$(date)] ($WORKING_DIRECTORY) generate validation plots"
    mu2e -s mcs* -c Offline/Validation/fcl/val.fcl 2>&1 | tee "$WORKING_DIRECTORY/val_pr.log"

    RC3=${PIPESTATUS[0]}
    echo "[$(date)] ($WORKING_DIRECTORY) validation plots return code is $RC3"
    if [ "$RC3" -ne 0 ]; then
        echo "[$(date)] ($WORKING_DIRECTORY) error while generating validation plots - abort"
        append_report_row "generate validation plots (${BUILDVER})" ":x:" "[Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/TBD.log)" # TODO: work out where this goes
        exit 1;
    fi

    echo "[$(date)] ($WORKING_DIRECTORY) move validation.root to $WORKSPACE"

    mv validation.root "$WORKSPACE/rev_${COMMIT_SHA_V}_${BUILDVER}_validation.root" || exit 1;

    exit 0;
)
exit $?