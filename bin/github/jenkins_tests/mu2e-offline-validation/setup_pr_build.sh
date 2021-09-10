#!/bin/bash

# Restores the cached build for the PR version being tested
# return code 0: success
# return code 1: error
# return code 2: merge error

NJOBS=16
export REPO=$(echo $REPOSITORY | sed 's|^.*/||')
export WORKING_DIRECTORY_PR="$WORKSPACE/pr"

function merge_repos() {
    cd ${WORKING_DIRECTORY_PR}/${REPO}
    if [ $? -ne 0 ]; then 
        return 2
    fi
    if [ "${NO_MERGE}" = "1" ]; then
        echo "[$(date)] Mu2e/$REPO - Checking out PR HEAD directly"
        git checkout ${COMMIT_SHA} #"pr${PULL_REQUEST}"
        git log -1
    else
        echo "[$(date)] Mu2e/$REPO - Checking out latest commit on base branch"
        git checkout ${MASTER_COMMIT_SHA}
        git log -1
    fi

    if [ "${TEST_WITH_PR}" != "" ]; then
        # comma separated list

        for pr in $(echo ${TEST_WITH_PR} | sed "s/,/ /g")
        do
            # if it starts with "#" then it is a PR in $REPO.
            if [[ $pr = \#* ]]; then
                REPO_NAME="$REPO"
                THE_PR=$( echo $pr | awk -F\# '{print $2}' )
                cd $WORKING_DIRECTORY_PR/$REPO
            elif [[ $pr = *\#* ]]; then
                # get the repository name
                REPO_NAME=$( echo $pr | awk -F\# '{print $1}' )
                THE_PR=$( echo $pr | awk -F\# '{print $2}' )

                # check it exists, and clone it into the workspace if it does not.
                if [ ! -d "$WORKING_DIRECTORY_PR/$REPO_NAME" ]; then
                    (
                        cd $WORKING_DIRECTORY_PR
                        git clone git@github.com:Mu2e/${REPO_NAME}.git ${REPO_NAME} || exit 2
                    )
                    if [ $? -ne 0 ]; then 
                        return 2
                    fi
                fi
                # change directory to it
                cd $WORKING_DIRECTORY_PR/$REPO_NAME || exit 2
            else
                # ???
                return 2
            fi

            git config user.email "you@example.com"
            git config user.name "Your Name"
            git fetch origin pull/${THE_PR}/head:pr${THE_PR}

            echo "[$(date)] Merging PR ${REPO_NAME}#${THE_PR} into ${REPO_NAME} as part of this test."

            THE_COMMIT_SHA=$(git rev-parse pr${THE_PR})

            # Merge it in
            git merge --no-ff pr${THE_PR} -m "merged #${THE_PR} as part of this test"
            if [ "$?" -gt 0 ]; then
                echo "[$(date)] Merge failure!"
                return 2
            fi
            CONFLICTS=$(git ls-files -u | wc -l)
            if [ "$CONFLICTS" -gt 0 ] ; then
                echo "[$(date)] Merge conflicts!"
                return 2
            fi

        done
    fi
    
    cd ${WORKING_DIRECTORY_PR}/${REPO}

    if [ "${NO_MERGE}" != "1" ]; then 
        echo "[$(date)] Merging PR#${PULL_REQUEST} at ${COMMIT_SHA}."
        git merge --no-ff ${COMMIT_SHA} -m "merged ${REPOSITORY} PR#${PULL_REQUEST} ${COMMIT_SHA}."
        if [ "$?" -gt 0 ]; then
            return 2
        fi
        CONFLICTS=$(git ls-files -u | wc -l)
        if [ "$CONFLICTS" -gt 0 ] ; then
            return 2
        fi
    fi

    return 0
}

rm -rf $WORKING_DIRECTORY_PR
mkdir -p $WORKING_DIRECTORY_PR
cd "$WORKING_DIRECTORY_PR" || exit 1

setup_build_repos "$REPOSITORY"

# switch to Offline and merge in the PR branch at the required master rev
cd "$WORKING_DIRECTORY_PR/$REPO" || exit 1
merge_repos || exit 2

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