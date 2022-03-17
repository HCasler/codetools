#!/bin/bash
# Helenka Casler, 2022
# hcasler@fnal.gov
# hcasler@gc.cuny.edu

# Reports a test failure due to the Jenkins job timing out

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export GH_COMMON_SCRIPT="$DIR/github/github_common.sh"

cd "$WORKSPACE" || exit 1;


function check_set() {
    if [ -z "$1" ]; then
        return 1; # not set!
    fi

    return 0;
}

echo "Checking we're in the expected Jenkins environment...";

check_set $REPOSITORY || exit 1;
check_set $PULL_REQUEST || exit 1;
check_set $COMMIT_SHA || exit 1;
check_set $MASTER_COMMIT_SHA || exit 1;

echo "OK!"

source $GH_COMMON_SCRIPT
setup_cmsbot

MU2E_POSTTEST_STATUSES=""

# scan for logfiles
# successes
successes=$(ls | grep log.SUCCESS)
failures=$(ls | grep log.FAILED)
timeouts=$(ls | grep log.TIMEOUT)

for goodTest in successes; do
    jobName=$(echo $goodTest | sed "s/log\.SUCCESS//g")
    append_report_row "$jobName" ":white_check_mark:" "[Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/$jobName.log)"
done
for badTest in failures; do
    jobName=$(echo $badTest | sed "s/log\.FAILED//g")
    append_report_row "$jobName" ":x:" "[Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/$jobName.log)"
done
for longTest in timeouts; do
    jobName=$(echo $longTest | sed "s/log\.TIMEOUT//g")
    append_report_row "$jobName" ":x:" "(timeout) [Log file](${JOB_URL}/${BUILD_NUMBER}/artifact/$jobName.log)"
done

# get job context
statContext="mu2e"
if [ $JOB_BASE_NAME == *build* ]; then
    statContext="mu2e/buildtest"
elif [[ $JOB_BASE_NAME == *validation* ]]; then
    statContext="mu2e/validation"
fi


cat > "$WORKSPACE"/gh-report.md <<- EOM
${COMMIT_SHA}
${statContext}
failure
The job timed out;
${JOB_URL}/${BUILD_NUMBER}/console
:umbrella: The tests timed out at ${COMMIT_SHA}.

EOM

cat >> "$WORKSPACE"/gh-report.md <<- EOM

| Test          | Result        | Details |
| ------------- |:-------------:| ------- |${MU2E_POSTTEST_STATUSES}

EOM

if [ "${NO_MERGE}" = "0" ]; then
    cat >> "$WORKSPACE"/gh-report.md <<- EOM

N.B. These results were obtained from a build of this Pull Request at ${COMMIT_SHA} after being merged into the base branch at ${MASTER_COMMIT_SHA}.

EOM
else
    cat >> "$WORKSPACE"/gh-report.md <<- EOM

N.B. These results were obtained from a build of this pull request branch at ${COMMIT_SHA}.

EOM
fi

cat >> "$WORKSPACE"/gh-report.md <<- EOM

For more information, please check the job page [here](${JOB_URL}/${BUILD_NUMBER}/console).
Build artifacts are deleted after 5 days. If this is not desired, select \`Keep this build forever\` on the job page.

EOM

cat >> "$WORKSPACE"/gh-report.md <<- EOM

For more information, please check the job page [here](${JOB_URL}/${BUILD_NUMBER}/console).
Build artifacts are deleted after 5 days. If this is not desired, select \`Keep this build forever\` on the job page.

EOM

# truncate scons logfile in place, removing time debug info
sed -i '/Command execution time:/d' scons.log
sed -i '/SConscript:/d' scons.log

${CMS_BOT_DIR}/upload-job-logfiles gh-report.md ${WORKSPACE}/*.log > gist-link.txt 2> upload_logfile_error_response.txt

if [ $? -ne 0 ]; then
    # do nothing for now, but maybe add an error message in future
    echo "Couldn't upload logfiles..."

else
    GIST_LINK=$( cat gist-link.txt )
    cat >> "$WORKSPACE"/gh-report.md <<- EOM

Log files have been uploaded [here.](${GIST_LINK})

EOM

fi


cmsbot_report "$WORKSPACE/gh-report.md"

echo "[$(date)] cleaning up old gists"
${CMS_BOT_DIR}/cleanup-old-gists

#${COMMIT_SHA} # commit sha
#mu2e/buildtest # context
#success # state
#The tests passed. # desc
#${JOB_URL}/${BUILD_NUMBER}/console # details link
#:sunny: The tests passed at ${COMMIT_SHA}. # beginning of content