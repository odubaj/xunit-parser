#!/bin/bash

#TODO
# pridat v importe do regularnych buildov tag non-scratch aby bolo mozne lahko filtrovat v historii
#treba ziskat info o scratch-buildoch a buidoch cez taskinfo -> brew taskinfo -v <task-id> + brew buildinfo <nvr> -> mas tu aj meno aj verziu, release, len to rozparsuj pekne
#poriesit userov a ich prihlasovanie cez curl
#poriesit jednotlive baliky aby boli ich vysledky importnute do spravnych projektov
#success rate opravit
#email server nastavit
#containery su nejake divne co sa tyka nvr a build_id

source functions.sh

USERNAME=$1
PASSWORD=$2
FILE=$3
ZIP_NAME=$4
SCRATCH=$5
NVR=$6
TASK_ID=$7
TEST_PLAN_NAME=$8
ISSUER=$9

TMP_FILE="reportportal-results.xml"
TASKINFO_FILE="taskinfo.txt"

# resolve correct project
PROJECT=$(get_project ${ZIP_NAME})

# get data about the task from brew
#brew taskinfo -v $TASK_ID > $TASKINFO_FILE
BUILD_ID="unknown" #$(grep "Build: " $TASKINFO_FILE | cut -d' ' -f3 | tr -d '()')

ZIP_FILE=$ZIP_NAME.zip

if [ $SCRATCH == "true" ]
then
  ZIP_FILE=$ZIP_NAME-scratch.zip
fi

if [ -z $BUILD_ID ]
then
  BUILD_ID="unknown"
fi

# create custom Xunit for ReportPortal
python3 standardize_xunit.py $FILE $TEST_PLAN_NAME $NVR $BUILD_ID $TASK_ID $SCRATCH $ISSUER > $TMP_FILE

zip -r $ZIP_FILE $TMP_FILE

# import data with appropriate tokens
UI_TOKEN=$(get_ui_token ${USERNAME} ${PASSWORD})

API_TOKEN=$(get_api_token ${UI_TOKEN})
echo $API_TOKEN

#find launch with same task-id
FOUND=$(get_launch_by_task_id ${PROJECT} ${API_TOKEN} ${TASK_ID})
echo $FOUND
number_to_merge=$(echo $FOUND | jq '.page.totalElements' --raw-output)
found_launch_id=$(echo $FOUND | jq '.content[0].id' --raw-output)
found_launch_uuid=$(echo $FOUND | jq '.content[0].uuid' --raw-output)

#import new launch
IMPORT=$(import_xunit ${PROJECT} ${API_TOKEN} ${ZIP_FILE} | jq '.message' --raw-output | cut -d' ' -f5)
echo $IMPORT

#merge launches
if [ $number_to_merge != 0 ]
then
  #find running item to be replaced
  RUNNING_ITEM=$(get_item_by_filter ${PROJECT} ${API_TOKEN} ${TASK_ID} ${TEST_PLAN_NAME} ${found_launch_id})
  echo $RUNNING_ITEM
  number_of_items=$(echo $RUNNING_ITEM | jq '.page.totalElements' --raw-output)

  #deleting running item if exists
  if [ $number_of_items != 0 ]
  then
    item_id=$(echo $RUNNING_ITEM | jq '.content[0].id' --raw-output)
    item_uuid=$(get_item_uuid ${PROJECT} ${API_TOKEN} ${item_id} | jq '.[0].uuid' --raw-output)
    result=$(stop_delete_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_id} ${item_uuid})
  fi

  #get data of existing launch
  IMPORTED=$(get_launch_by_uuid ${PROJECT} ${API_TOKEN} ${IMPORT} | jq '.content' --raw-output)
  echo $IMPORTED
  FOUND=$(echo $FOUND | jq '.content' --raw-output)

  #creating merge string for specified launches
  merge_string=$(python3 merge_launches.py "$FOUND" "$IMPORTED")

  #merging launches
  MERGED=$(merge_launches ${PROJECT} ${API_TOKEN} "${merge_string}")
  echo $MERGED
fi

rm $ZIP_FILE

