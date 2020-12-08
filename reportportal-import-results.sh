#!/bin/bash

# Script which downloads import and parser scripts, executes them and creates
# new XUnit reportportal-results.xml

# topicy z ktorych budem tahat:
# redhat-module.test.complete
# brew-build.test.complete

# musia mat tag 0.1.*

XUNIT_ORIGINAL="results.xml"
IMPORT_SCRIPT="main.sh"
PARSER="standardize_xunit.py"
USER="superadmin"
PASSWORD="aQsWdEfR1029"
SCRIPT_URL="https://raw.githubusercontent.com/odubaj/xunit-parser/master"
DATAGREPPER_JSON="datagrepper.json"
UMB_URL=""
VERSION_PATTERN="0\.1\.[0-9]*"
URL_PATTERN="http[s]*:*"
COMPONENT=""

# TODO: tu treba ziskat url, ktore spadaju pod topicy

curl -s $UMB_URL > $DATAGREPPER_JSON
xunit_version=$(cat $DATAGREPPER_JSON | jq -r .msg.version)
if [ -z $xunit_version ] || [[ ! $xunit_version =~ $VERSION_PATTERN ]]; then
    rm $DATAGREPPER_JSON;
    exit 0;
fi

HASH=$(cat $DATAGREPPER_JSON | jq -r .msg.xunit)
if [ -z $HASH ] || [ $HASH == "null" ] ; then
    rm $DATAGREPPER_JSON;
    exit 0;
fi

if [[ $HASH =~ $URL_PATTERN ]]; then
    curl -s $HASH > $XUNIT_ORIGINAL
else
    python3 -c "import zlib,base64; print(zlib.decompress(base64.b64decode($HASH)))" > $XUNIT_ORIGINAL
fi

COMPONENT=HASH=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.component)

wget $SCRIPT_URL/$IMPORT_SCRIPT
wget $SCRIPT_URL/$PARSER
chmod +x $IMPORT_SCRIPT

./$IMPORT_SCRIPT $USER $PASSWORD $XUNIT_ORIGINAL $COMPONENT

