#! /bin/bash

# Cleans up workspace from previous builds.
# This gets called by gh_pr_bootstrap.
# The Production tests require that files (but not all directories) be cleared.
# Any old build directories should also be cleared.

echo "Delete files in workspace from previous builds (not directories)"
rm $WORKSPACE/* # removes files only - we only expect folders to exist in the workspace at the start of the build.
rm $WORKSPACE/.sconsign.dblite
rm -rf $WORKSPACE/build # this shouldn't be hanging around either
echo "Workspace now:"
ls -lah
echo ""
echo ""