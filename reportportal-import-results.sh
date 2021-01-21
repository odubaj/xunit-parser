#!/bin/bash

# Script checks corret format of UMB message
# and executes approriate script for brew-builds

IMPORT_SCRIPT="main.sh"
RUNNING_SCRIPT="script.sh"
ERROR_SCRIPT="error.sh"
USER="superadmin"
PASSWORD="aQsWdEfR1029"
#PASSWORD="erebus"
DATAGREPPER_JSON=$1
URL_PATTERN="http[s]*:*"

TASK_ID=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.id)
namespace=$(cat $DATAGREPPER_JSON | jq -r .msg.namespace)
type=$(cat $DATAGREPPER_JSON | jq -r .msg.type)
TEST_PLAN_NAME=$namespace.$type."functional"
time=$2
XUNIT_ORIGINAL="$TASK_ID/$TEST_PLAN_NAME-$time-original-res.xml"
XUNIT_HASH="$TASK_ID/$TEST_PLAN_NAME-$time-original-xunit.txt"

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
        echo $HASH > $XUNIT_HASH
        python3 -c "from decode_xunit import decode_xunit; decode_xunit('$XUNIT_HASH')" > $XUNIT_ORIGINAL
    fi
elif [ $topic == "/topic/VirtualTopic.eng.ci.brew-build.test.error" ] ; then
    LOG1=$(cat $DATAGREPPER_JSON | jq -r .msg.run.debug)
    LOG2=$(cat $DATAGREPPER_JSON | jq -r .msg.run.log)
    LOG3=$(cat $DATAGREPPER_JSON | jq -r .msg.run.log_raw)
fi

COMPONENT=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.component)
SCRATCH=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.scratch)
NVR=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.nvr)
ISSUER=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.issuer)
REPORT_LOG="report.log"

echo " --------------------------------------------------" >> $TASK_ID/$REPORT_LOG
echo " received message from topic $topic - message valid" >> $TASK_ID/$REPORT_LOG

chmod +x $IMPORT_SCRIPT
chmod +x $RUNNING_SCRIPT
chmod +x $ERROR_SCRIPT

if [ $topic == "/topic/VirtualTopic.eng.ci.brew-build.test.complete" ] ; then
    ./$IMPORT_SCRIPT $USER $PASSWORD $XUNIT_ORIGINAL $COMPONENT $SCRATCH $NVR $TASK_ID $TEST_PLAN_NAME $ISSUER $time
elif [ $topic == "/topic/VirtualTopic.eng.ci.brew-build.test.running" ] ; then
    ./$RUNNING_SCRIPT $USER $PASSWORD $COMPONENT $SCRATCH $NVR $TASK_ID $TEST_PLAN_NAME $ISSUER
else
    ./$ERROR_SCRIPT $USER $PASSWORD $COMPONENT $SCRATCH $NVR $TASK_ID $TEST_PLAN_NAME $ISSUER $LOG1 $LOG2 $LOG3
fi

