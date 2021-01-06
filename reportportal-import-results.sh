#!/bin/bash

# Script which downloads import and parser scripts, executes them and creates
# new XUnit reportportal-results.xml

# topicy z ktorych budem tahat:
# redhat-module.test.complete
# brew-build.test.complete

# musia mat tag 0.1.*

XUNIT_ORIGINAL="results.xml"
IMPORT_SCRIPT="main.sh"
RUNNING_SCRIPT="script.sh"
ERROR_SCRIPT="error.sh"
PARSER="standardize_xunit.py"
USER="superadmin"
# tuto zmena
PASSWORD="erebus"
SCRIPT_URL="https://raw.githubusercontent.com/odubaj/xunit-parser/master"
DATAGREPPER_JSON="datagrepper.json"
UMB_URL=$1
VERSION_PATTERN="0\.1\.[0-9]*"
URL_PATTERN="http[s]*:*"

curl -s $UMB_URL > $DATAGREPPER_JSON

category=$(cat $DATAGREPPER_JSON | jq -r .msg.category)
if [ $category != "functional" ] ; then
    echo "non-functional tests"
    rm $DATAGREPPER_JSON;
    exit 0;
fi

quality_engineering=$(cat $DATAGREPPER_JSON | jq -r .msg.ci.email)
if [ $quality_engineering != "baseos-ci@redhat.com" ] ; then
    echo "bad QE"
    rm $DATAGREPPER_JSON;
    exit 0;
fi

xunit_version=$(cat $DATAGREPPER_JSON | jq -r .msg.version)
if [ -z $xunit_version ] || [[ ! $xunit_version =~ $VERSION_PATTERN ]]; then
    echo "bad version"
    rm $DATAGREPPER_JSON;
    exit 0;
fi

topic=$(cat $DATAGREPPER_JSON | jq -r .topic)
if [ $topic == "/topic/VirtualTopic.eng.ci.brew-build.test.complete" ] ; then
    HASH=$(cat $DATAGREPPER_JSON | jq -r .msg.xunit)
    if [ -z $HASH ] || [ $HASH == "null" ] ; then
        echo "no xunit"
        rm $DATAGREPPER_JSON;
        exit 0;
    fi

    if [[ $HASH =~ $URL_PATTERN ]]; then
        curl -s $HASH > $XUNIT_ORIGINAL
    else
        python3 -c "import zlib,base64; print(zlib.decompress(base64.b64decode('$HASH')).decode('utf-8') )" > $XUNIT_ORIGINAL
    fi
fi

COMPONENT=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.component)
SCRATCH=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.scratch)
NVR=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.nvr)
TASK_ID=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.id)
namespace=$(cat $DATAGREPPER_JSON | jq -r .msg.namespace)
type=$(cat $DATAGREPPER_JSON | jq -r .msg.type)
TEST_PLAN_NAME=$namespace.$type."functional"
ISSUER=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.issuer)

#wget $SCRIPT_URL/$IMPORT_SCRIPT
#wget $SCRIPT_URL/$PARSER
#wget $SCRIPT_URL/$RUNNING_SCRIPT
#wget $SCRIPT_URL/$ERROR_SCRIPT
chmod +x $IMPORT_SCRIPT
chmod +x $RUNNING_SCRIPT
chmod +x $ERROR_SCRIPT

if [ $topic == "/topic/VirtualTopic.eng.ci.brew-build.test.complete" ] ; then
    ./$IMPORT_SCRIPT $USER $PASSWORD $XUNIT_ORIGINAL $COMPONENT $SCRATCH $NVR $TASK_ID $TEST_PLAN_NAME $ISSUER
elif [ $topic == "/topic/VirtualTopic.eng.ci.brew-build.test.running" ] ; then
    ./$RUNNING_SCRIPT $USER $PASSWORD $COMPONENT $SCRATCH $NVR $TASK_ID $TEST_PLAN_NAME $ISSUER
else
    ./$ERROR_SCRIPT $USER $PASSWORD $COMPONENT $SCRATCH $TASK_ID $TEST_PLAN_NAME
fi

