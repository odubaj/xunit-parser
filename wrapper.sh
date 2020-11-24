#!/bin/bash

# If we're running on the staging Jenkins, don't bother with cold store.
if [ "$JENKINS_MASTER_URL" != "https://baseos-stg-jenkins.rhev-ci-vms.eng.rdu2.redhat.com" ]; then
    exit 1
fi

XUNIT_ORIGINAL="results.xml"
IMPORT_SCRIPT="main.sh"
PARSER="standardize_xunit.py"
USER="superadmin"
PASSWORD="erebus"
SCRIPT_URL="https://raw.githubusercontent.com/odubaj/xunit-parser/master"

wget $SCRIPT_URL/$IMPORT_SCRIPT
wget $SCRIPT_URL/$PARSER
chmod +x $IMPORT_SCRIPT

./$IMPORT_SCRIPT $USER $PASSWORD $XUNIT_ORIGINAL

rm $IMPORT_SCRIPT $PARSER

