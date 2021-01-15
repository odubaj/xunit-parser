#!/bin/bash

XUNIT_ORIGINAL="results.xml"
IMPORT_SCRIPT="main.sh"
RUNNING_SCRIPT="script.sh"
ERROR_SCRIPT="error.sh"
USER="superadmin"
PASSWORD="aQsWdEfR1029"
#PASSWORD="erebus"
DATAGREPPER_JSON="datagrepper.json"
URL_PATTERN="http[s]*:*"

topic=$(cat $DATAGREPPER_JSON | jq -r .topic)
if [ $topic == "/topic/VirtualTopic.eng.ci.redhat-module.test.complete" ] ; then
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
elif [ $topic == "/topic/VirtualTopic.eng.ci.redhat-module.test.error" ] ; then
    LOG1=$(cat $DATAGREPPER_JSON | jq -r .msg.run.debug)
    LOG2=$(cat $DATAGREPPER_JSON | jq -r .msg.run.log)
    LOG3=$(cat $DATAGREPPER_JSON | jq -r .msg.run.log_raw)
fi

COMPONENT=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.name)
SCRATCH="false" #$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.scratch)
NVR=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.nsvc)
TASK_ID=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.id)
namespace=$(cat $DATAGREPPER_JSON | jq -r .msg.namespace)
type=$(cat $DATAGREPPER_JSON | jq -r .msg.type)
TEST_PLAN_NAME=$namespace.$type."functional"
ISSUER=$(cat $DATAGREPPER_JSON | jq -r .msg.artifact.issuer)
REPORT_LOG="report.log"
topic_name=$(echo $topic | cut -d'.' -f6)

mkdir -p $TASK_ID
echo " --------------------------------------------------" >> $TASK_ID/$REPORT_LOG
echo " received message from topic $topic - message valid" >> $TASK_ID/$REPORT_LOG
mv $DATAGREPPER_JSON $TASK_ID/$TEST_PLAN_NAME-$topic_name-$DATAGREPPER_JSON

chmod +x $IMPORT_SCRIPT
chmod +x $RUNNING_SCRIPT
chmod +x $ERROR_SCRIPT

if [ $topic == "/topic/VirtualTopic.eng.ci.redhat-module.test.complete" ] ; then
    ./$IMPORT_SCRIPT $USER $PASSWORD $XUNIT_ORIGINAL $COMPONENT $SCRATCH $NVR $TASK_ID $TEST_PLAN_NAME $ISSUER
elif [ $topic == "/topic/VirtualTopic.eng.ci.redhat-module.test.running" ] ; then
    ./$RUNNING_SCRIPT $USER $PASSWORD $COMPONENT $SCRATCH $NVR $TASK_ID $TEST_PLAN_NAME $ISSUER
else
    ./$ERROR_SCRIPT $USER $PASSWORD $COMPONENT $SCRATCH $TASK_ID $TEST_PLAN_NAME $LOG1 $LOG2 $LOG3
fi

