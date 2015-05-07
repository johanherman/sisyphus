#!/bin/bash

set -o pipefail
set -o nounset 

# To be called from cron with e.g. 
# 30 23  *   *   *   flock -n /tmp/a2009002_verifying /proj/a2009002/to_verify/verify.sh

#SISYPHUS="/proj/a2009002/Software/Sisyphus"
ROOT="/proj/a2009002/to_verify/"

cd "${ROOT}/queue" || (echo "Failed to cd to ROOT queue" && exit 1)

for VERIFY in *; do
   mv "${VERIFY}" ../ongoing/ || (echo "Failed to mv ${VERIFY} to ongoing" && exit 1)
   VERIFYPATH="${ROOT}/ongoing/${VERIFY}/" 
   SISYPHUS="${VERIFYPATH}/Sisyphus/"

   ${SISYPHUS}/archive2swestore.pl -runfolder ${VERIFYPATH} -config ${SISYPHUS}/sisyphus.yml -verifyonly 

   # TODO: Skicka mail om att verifieringen har börjat. 
   # TODO: Skicka mail om att verifieringen lyckades/misslyckades. 

   RETVAL = $?

   [ $RETVAL -eq 0 ] && echo "Success" && mv -f ../ongoing/"${RUN}" ../done/ && exit 0
   [ $RETVAL -ne 0 ] && echo "Failed" && mv -f ../ongoing/"${RUN}" ../failed/ && exit 1
done