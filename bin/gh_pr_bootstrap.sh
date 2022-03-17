#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk
# sets up job environment and calls the job.sh script in the relevant directory

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export JENKINS_TESTS_DIR="$DIR/github/jenkins_tests"
export CLANGTOOLS_UTIL_DIR="$DIR/../clangtools_utilities"
export TESTSCRIPT_DIR="$JENKINS_TESTS_DIR/$1"
export REQUIRED_BUILD_REPOS_SHORT=("Offline" "Production")
export GH_COMMON_SCRIPT="$DIR/github/github_common.sh"

# if the PR is trying to merge into this branch, make sure all other repos
# in the build are set up in this branch by default
BRANCHNAMES_MUST_MATCH="Mu2eII_SM21"

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


# clean workspace from previous build 
echo "Delete files in workspace from previous builds (not directories)"
rm $WORKSPACE/* # removes files only - we only expect folders to exist in the workspace at the start of the build.
rm $WORKSPACE/.sconsign.dblite
rm -rf $WORKSPACE/build # this shouldn't be hanging around either
echo "Workspace now:"
ls -lah
echo ""
echo ""

echo "Bootstrapping job $1..."


JOB_SCRIPT="${TESTSCRIPT_DIR}/job.sh"

if [ ! -f "$JOB_SCRIPT" ]; then
    echo "Fatal error running job type $1 - could not find $JOB_SCRIPT."
    exit 1;
fi

echo "Setting up job environment..."


rm -rf *.log *.md *.patch > /dev/null 2>&1

function print_jobinfo() {
    echo "[`date`] print_jobinfo"
    echo "[`date`] printenv"
    printenv

    echo "[`date`] df -h"
    df -h

    echo "[`date`] quota"
    quota -v

    echo "[`date`] PWD"
    pwd
    export LOCAL_DIR=$PWD

    echo "[`date`] ls of local dir at start"
    ls -al

    echo "[`date`] cpuinfo"
    cat /proc/cpuinfo | head -30

}


function setup_build_repos() {
    # setup_build_repos Mu2e/Offline if you are testing Offline
    # setup_build_repos Mu2e/Production if you are testing Production
    export REPO=$(echo $1 | sed 's|^.*/||')
    export REPO_FULLNAME=$1
    base_branch=main
    # get the name of the branch this PR is requesting to merge into
    branch_filename="repo${REPO}_pr${PULL_REQUEST}_baseBranch.txt"
    cmsbot_write_pr_base $REPO_FULLNAME $PULL_REQUEST $branch_filename True || echo "Failed to retrieve base branch name for repo ${REPO_FULLNAME} PR ${PULL_REQUEST}"
    if [ -f $branch_filename ]; then
        base_branch=$(cat $branch_filename)
    fi
    (
        # clean up any previous builds
        rm -rf $REPO .sconsign.dblite build "${REQUIRED_BUILD_REPOS_SHORT[@]}"
        # clone all the required repos
        for reqrepo in "${REQUIRED_BUILD_REPOS_SHORT[@]}";
        do
            git clone "https://github.com/Mu2e/${reqrepo}"
            if [ ${base_branch} == ${BRANCHNAMES_MUST_MATCH} ]; then
                (
                    cd $reqrepo
                    git fetch origin ${base_branch} || echo "Failed to fetch branch ${base_branch} of repo Mu2e/${reqrepo}"
                    git checkout ${base_branch}  || echo "Failed to checkout branch ${base_branch} of repo Mu2e/${reqrepo}"
                )
            fi
        done
        # make sure we got our PR repo
        if [ ! -d "${REPO}" ]; then
            git clone "https://github.com/$REPO_FULLNAME"
        fi

        cd $REPO

        git config user.email "you@example.com"
        git config user.name "Your Name"

        git fetch origin pull/${PULL_REQUEST}/head:pr${PULL_REQUEST}
    )

}



echo "Running job now."

print_jobinfo

(
    source $GH_COMMON_SCRIPT
    source $JOB_SCRIPT
)
JOB_STATUS=$?

echo "Job finished with status $JOB_STATUS."
exit $JOB_STATUS
