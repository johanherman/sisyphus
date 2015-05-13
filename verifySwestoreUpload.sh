#!/bin/bash

set -o pipefail
set -o nounset 

# To be called from cron with e.g. 
# 30 23  *   *   *   flock -n /tmp/a2009002_verifying /proj/a2009002/to_verify/verify.sh

#SISYPHUS="/proj/a2009002/Software/Sisyphus"
#ROOT="/proj/a2009002/to_verify/"
ROOT="/home/johanhe/to_verify/"
MAIL_ADDR="johan.hermansson@medsci.uu.se"

cd "${ROOT}/queue" || (echo "Failed to cd to ROOT queue" && exit 1)

# Verifying serially for now.
# We could launch ssverify.sh here instead. 
for VERIFY in *; do
   MODIFIED=$(stat -c %Y ${VERIFY}) || (echo "Failed to get modification time" && exit 1) # Number of seconds since Epoch (modification time). 
   NOW=$(date +%s) || (echo "Failed to get current date" && exit 1) # Number of seconds since Epoch (current time).
   WAIT=$((4*24*60*60)) # Number of seconds we should wait until verifying.
   DIFF=$((${NOW}-${MODIFIED})) # Number of seconds we have waited. 

   if [[ ${DIFF} -gt ${WAIT} ]]; then 
   	mv "${VERIFY}" ../ongoing/ || (echo "Failed to mv ${VERIFY} to ongoing" && exit 1)
   	VERIFYPATH="${ROOT}/ongoing/${VERIFY}/" 
   	SISYPHUS="${VERIFYPATH}/Sisyphus/"

   	echo "Following command has now started to run: ${SISYPHUS}/archive2swestore.pl -runfolder ${VERIFYPATH} -config ${SISYPHUS}/sisyphus.yml -verifyonly" | mail -s "Swestore verification started for ${VERIFY}" ${MAIL_ADDR}
   	${SISYPHUS}/archive2swestore.pl -runfolder ${VERIFYPATH} -config ${SISYPHUS}/sisyphus.yml -verifyonly 

   	RETVAL = $?

   	if [[ ${RETVAL} -eq 0 ]]; then 
		   echo "Verification successful" 
		   mv -f ../ongoing/"${VERIFY}" ../done/ || (echo "Failed to move to done folder" && exit 1)
		   echo "Successfully verified ${VERIFY} on Swestore, and has moved folder to 'done'." | mail -s "Swestore verification successful for ${VERIFY}" ${MAIL_ADDR}
		   exit 0
   	fi

   	if [[ ${RETVAL} -ne 0 ]]; then 
		   echo "Verification failed"
		   mv -f ../ongoing/"${RUN}" ../failed/ || (echo "Failed to move to failed folder" && exit 1)
		   echo "Swestore verification of ${VERIFY} failed. Folder has been moved to 'failed'." | mail -s "Swestore verification failed for ${VERIFY}" ${MAIL_ADDR} 
		   exit 1
   	fi
  fi
done
