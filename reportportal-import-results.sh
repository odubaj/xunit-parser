#!/bin/bash

# Script which downloads import and parser scripts, executes them and creates
# new XUnit reportportal-results.xml

# If we're not running on the staging Jenkins, do nothing.
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

