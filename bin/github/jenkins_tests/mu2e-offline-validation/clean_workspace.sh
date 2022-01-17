#! /bin/bash

# Cleans up workspace from previous builds.
# This gets called by gh_pr_bootstrap.
# The validation tests require that most files be cleared -- but NOT the build
# artifacts from the build we're validating.
# Also hang on to the main-branch ("master") build cache and validation 
# histograms, if they exist.
# Any old build directories should also be cleared.

KEEP_DIR_NAME="${WORKSPACE}/need_for_tests"

echo "Delete files in workspace from previous builds (not directories), keeping the right build artifacts for commit ${COMMIT_SHA}"
PR_CACHE_FILE_NAME="rev_${COMMIT_SHA}_pr_lib.tar.gz"
MASTER_CACHE_FILE_NAME="rev_${MASTER_COMMIT_SHA}_master_lib.tar.gz"
MASTER_VALIDATION_NAME="rev_${MASTER_COMMIT_SHA}_master_validation.root"
MASTER_SHA_TXT="master_commit_sha.txt"
OLD_PROPERTIES_PATTERN="trigger-mu2e-build*"
# move these files so they don't get deleted during pre-run cleanup
mkdir -p $KEEP_DIR_NAME
mv "${WORKSPACE}/${PR_CACHE_FILE_NAME}"  "${KEEP_DIR_NAME}/${PR_CACHE_FILE_NAME}"
mv "${WORKSPACE}/${MASTER_CACHE_FILE_NAME}" "${KEEP_DIR_NAME}/${MASTER_CACHE_FILE_NAME}"
mv "${WORKSPACE}/${MASTER_VALIDATION_NAME}" "${KEEP_DIR_NAME}/${MASTER_VALIDATION_NAME}"
mv "${WORKSPACE}/${MASTER_SHA_TXT}" "${KEEP_DIR_NAME}/${MASTER_SHA_TXT}"
mv "${WORKSPACE}/${OLD_PROPERTIES_PATTERN}" "${KEEP_DIR_NAME}/${OLD_PROPERTIES_PATTERN}"
# delete all other files
rm $WORKSPACE/* # removes files only - we only expect folders to exist in the workspace at the start of the build.
rm $WORKSPACE/.sconsign.dblite
rm -rf $WORKSPACE/build # this shouldn't be hanging around either
# put the saved artifacts back
mv "${KEEP_DIR_NAME}/${PR_CACHE_FILE_NAME}" "${WORKSPACE}/${PR_CACHE_FILE_NAME}" 
mv "${KEEP_DIR_NAME}/${MASTER_CACHE_FILE_NAME}" "${WORKSPACE}/${MASTER_CACHE_FILE_NAME}"
mv "${KEEP_DIR_NAME}/${MASTER_VALIDATION_NAME}" "${WORKSPACE}/${MASTER_VALIDATION_NAME}"
mv "${KEEP_DIR_NAME}/${MASTER_SHA_TXT}" "${WORKSPACE}/${MASTER_SHA_TXT}"
mv "${KEEP_DIR_NAME}/${OLD_PROPERTIES_PATTERN}" "${WORKSPACE}/${OLD_PROPERTIES_PATTERN}"
# we don't need this anymore
rm -rf $KEEP_DIR_NAME
echo "Workspace now:"
ls -lah
echo ""
echo ""