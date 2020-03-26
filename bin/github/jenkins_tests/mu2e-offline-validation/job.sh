#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

cd "$WORKSPACE" || exit

echo "[$(date)] setup CMS-BOT/mu2e"
setup_cmsbot

if [ -f "$WORKSPACE/master_commit_sha.txt" ]; then
  BUILDTEST_MASTER_SHA=`cat $WORKSPACE/master_commit_sha.txt`

  if [ "$BUILDTEST_MASTER_SHA" != "$MASTER_COMMIT_SHA" ]; then
      echo "[`date`] WARNING: MASTER REV MISMATCH WITH BUILD TEST MASTER REV"
      echo "[`date`] This means that commits in master that were not built in a build test"
      echo "[`date`] may affect the comparison results. Review these results with caution."
  fi
else
	echo "[`date`] WARNING: could not find master_commit_sha.txt..."
fi

if [ ! -f "$WORKSPACE/rev_${COMMIT_SHA}_pr_lib.tar.gz" ]; then
	cat > gh-run-report.md <<- EOM
${COMMIT_SHA}
mu2e/validation
error
Validation cannot be run before a build test.
${JOB_URL}/${BUILD_NUMBER}/console
The archived shared libraries from build test at ${COMMIT_SHA} cannot be found.

If you've just run a build test, you should wait at least 2 minutes before triggering this job.

If it's been more than 5 days since the build test was run, you should run it again.

EOM
    cmsbot_report gh-run-report.md
    exit 1;
fi

cd "$WORKSPACE" || exit 1

# report that the job script is now running

cat > gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/validation
pending
Validation is running in Jenkins.
${JOB_URL}/${BUILD_NUMBER}/console
NOCOMMENT

EOM
cmsbot_report gh-report.md

# parallelise for speed.
(
    echo "[$(date)] set up PR version"
    (
        source "${TESTSCRIPT_DIR}/setup_pr_build.sh"
    ) &
    PR_BUILD_PID=$!

    echo "[$(date)] set up master"
    (
        source "${TESTSCRIPT_DIR}/setup_master_build.sh"
    ) &
    MASTER_BUILD_PID=$!

    wait $PR_BUILD_PID;
    PR_RESTORE_OUTCOME=$?

    wait $MASTER_BUILD_PID;
    MASTER_BUILD_OUTCOME=$?

    if [ $PR_RESTORE_OUTCOME -ne 0 ]; then
        echo "[$(date)] PR build could not be restored (return code $PR_RESTORE_OUTCOME) - abort."
        exit 1;
    fi

    if [ $MASTER_BUILD_OUTCOME -ne 2 ]; then
        if [ $MASTER_BUILD_OUTCOME -ne 0 ]; then
            echo "[$(date)] master build could not be restored or built - abort."
            exit 1;
        fi
    else
        exit 2;
    fi
    exit 0;
)
RESTORE_BUILD_OUTCOME=$?
DO_MASTER_VALPLOT=1
if [ $RESTORE_BUILD_OUTCOME == 2 ]; then
    RESTORE_BUILD_OUTCOME=0
    DO_MASTER_VALPLOT=0
fi

if [ $RESTORE_BUILD_OUTCOME -ne 0 ]; then
    echo "[$(date)] Failure while setting up master and PR build versions - abort."

    cat > gh-run-report.md <<- EOM
${COMMIT_SHA}
mu2e/validation
error
An error occured during the setup of master and PR build versions.
${JOB_URL}/${BUILD_NUMBER}/console
:-1: An error occured in the validation job.

Please review the [logfile](${JOB_URL}/${BUILD_NUMBER}/console) and try again.

EOM
    cmsbot_report gh-run-report.md
    exit 1;
fi

echo "[$(date)] PR and master builds are ready. generate plots..."

# run validation jobs for each build version in parallel.
(
    if [ $DO_MASTER_VALPLOT -ne 0 ]; then
        . ${TESTSCRIPT_DIR}/valplot.sh master ceSimReco ${MASTER_COMMIT_SHA} &
        MASTER_VAL_PID=$!
    fi

    . ${TESTSCRIPT_DIR}/valplot.sh pr ceSimReco ${COMMIT_SHA} &
    PR_VAL_PID=$!

    wait $PR_VAL_PID;
    PR_VAL_OUTCOME=$?

    if [ $DO_MASTER_VALPLOT -ne 0 ]; then
        wait $MASTER_VAL_PID;
        MASTER_VAL_OUTCOME=$?
    else
        MASTER_VAL_OUTCOME=0
    fi

    if [ $PR_VAL_OUTCOME -ne 0 ]; then
        echo "[$(date)] PR validation rootfile not made - abort."
        exit 1;
    fi

    if [ $MASTER_VAL_OUTCOME -ne 0 ]; then
        echo "[$(date)] master validation rootfile not made - abort."
        exit 1;
    fi
    exit 0;
)

if [ $? -ne 0 ]; then
    echo "[$(date)] Failure while generating validation plots - abort."

    cat > gh-run-report.md <<- EOM
${COMMIT_SHA}
mu2e/validation
error
An error occured during the ceSimReco and val plot generation step.
${JOB_URL}/${BUILD_NUMBER}/console
:-1: An error occured in validation during the ceSimReco and val plot generation step.

Please review the [logfile](${JOB_URL}/${BUILD_NUMBER}/console) and try again.

EOM
    cmsbot_report gh-run-report.md
    exit 1;
fi

echo "[$(date)] PR and master validation plots are ready - generate comparison..."

(
    source ${TESTSCRIPT_DIR}/valcompare.sh
)

if [ $? -ne 0 ]; then
    echo "[$(date)] Failure while generating comparison - abort."

    cat > gh-run-report.md <<- EOM
${COMMIT_SHA}
mu2e/validation
error
An error occured during comparison (valCompare).
${JOB_URL}/${BUILD_NUMBER}/console
:-1: An error occured in validation during comparison (valCompare).

Please review the [logfile](${JOB_URL}/${BUILD_NUMBER}/console) and try again.

EOM
    cmsbot_report gh-run-report.md
    exit 1;
fi

echo "[$(date)] report successful outcome"

VAL_COMP_SUMMARY=$(cat valCompareSummary.log | head -n 12)

VALPLOT_LINK="${JOB_URL}/${BUILD_NUMBER}/artifact/valOutput_PR${PULL_REQUEST}_${COMMIT_SHA}_master_${MASTER_COMMIT_SHA}.tar.gz"
VALPLOT_LINKTWO="${JOB_URL}/${BUILD_NUMBER}/artifact/valOutput/pr${PULL_REQUEST}/rev${COMMIT_SHA}/result.html"

cat > $WORKSPACE/gh-report.md <<- EOM
${COMMIT_SHA}
mu2e/validation
success
The validation ran successfully.
${JOB_URL}/${BUILD_NUMBER}/console
:+1: A comparison was generated between these revisions:
- master build version: rev ${MASTER_COMMIT_SHA}
- PR build version: rev ${COMMIT_SHA}

#### valCompare Summary

\`\`\`
${VAL_COMP_SUMMARY}
\`\`\`

Validation plots are [viewable here](${VALPLOT_LINKTWO}), and can be [downloaded here](${VALPLOT_LINK}).
For full job output, please see [this link.](${JOB_URL}/${BUILD_NUMBER}).

EOM
cmsbot_report "$WORKSPACE/gh-report.md"

exit 0;