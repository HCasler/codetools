#!/bin/bash

echo "[`date`] start"
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


REPORT=nightly-build-`date +"%Y-%m-%d.txt"`
VALFILE=val-ceSimReco-5000-nightly_`date +"%Y-%m-%d"`-0.root

echo "[`date`] source products common"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
echo "[`date`] setup mu2e"
setup mu2e
setup codetools

echo "[`date`] printenv after setup"
printenv

echo "[`date`] clone offline"
#git clone http://cdcvs.fnal.gov/projects/mu2eofflinesoftwaremu2eoffline/Offline.git
git clone https://github.com/mu2e/Offline
echo "[`date`] cd Offline"
cd Offline

echo "[`date`] print commit"
git show
git rev-parse HEAD

echo "[`date`] source setup"
source setup.sh

echo "Nightly build " > $REPORT

echo "[`date`] start scons" | tee -a $REPORT
scons -j 16
RC1=$?
echo "[`date`] scons return code $RC1" | tee -a $REPORT

mu2e -c Mu2eG4/fcl/g4test_03.fcl
RC2=$?
echo "[`date`] g4test_03 return code $RC2" | tee -a $REPORT

# surfacecheck
mu2e -c Mu2eG4/fcl/surfaceCheck.fcl >& surfaceCheck.log
RC3=$?
echo "[`date`] surfaceCheck exe return code $RC3" | tee -a $REPORT

VOLCHECKG=`egrep 'Checking overlaps for volume' surfaceCheck.log | grep OK | wc -l`
VOLCHECKB=`egrep 'Checking overlaps for volume' surfaceCheck.log | grep -v OK | wc -l`
echo "Volume checks:  OK=${VOLCHECKG},  not OK=$VOLCHECKB" | tee -a $REPORT
egrep 'Checking overlaps for volume' surfaceCheck.log | grep -v OK | tee -a $REPORT

# rootOverlaps
rootOverlaps.sh | tee -a $REPORT
RC4=${PIPESTATUS[0]}
echo "[`date`] root overlap checks $RC4" | tee -a $REPORT

# transportOnly
mu2e -n 5 -c Mu2eG4/fcl/transportOnly.fcl
RC5=$?
echo "[`date`] transportOnly exe return code $RC5" | tee -a $REPORT

# potons on target
mu2e -c JobConfig/beam/PS.fcl -n 100
RC6=$?
echo "[`date`] PS (POT) return code $RC6" | tee -a $REPORT

# ceSimReco
mu2e -n 5000 -c Validation/fcl/ceSimReco.fcl
RC7=$?
echo "[`date`] ceSimReco exe return code $RC7" | tee -a $REPORT

# g4study
mu2e -n 5 -c Mu2eG4/g4study/g4study.fcl
RC8=$?
echo "[`date`] g4study exe return code $RC8" | tee -a $REPORT

RC=$(($RC1+$RC2+$RC3+$VOLCHECKB+$RC4+$RC5+$RC6+$RC7+$RC8))
echo "Return code before validation $RC" | tee -a $REPORT

#
# validation hists
#

mu2e -s mcs.owner.val-ceSimReco.dsconf.seq.art -c Validation/fcl/val.fcl 
RC9=$?
echo "[`date`] validation exe return code $RC9" | tee -a $REPORT

cp validation.root ../copyBack/$VALFILE

echo "[`date`] ls of Offline dir"
ls -al

cp $REPORT ../copyBack
cd ..
echo "[`date`] ls of local dir"
ls -al
echo "[`date`] ls of copyBack"
ls -al copyBack


exit $RC
