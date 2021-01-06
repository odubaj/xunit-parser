#!/bin/bash

source functions.sh

USERNAME=$1
PASSWORD=$2
ZIP_NAME=$3
SCRATCH=$4
NVR=$5
TASK_ID=$6
TEST_PLAN_NAME=$7
ISSUER=$8

# resolve correct project
PROJECT=$(get_project ${ZIP_NAME})

if [ $SCRATCH == "true" ]
then
  ZIP_NAME=$ZIP_NAME-scratch.zip
fi

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

#merge launches
if [ $number_to_merge != 0 ]
then
  #creating test-suite
   test_suite=$(create_test_suite ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${TEST_PLAN_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER})
else
  #creating new launch
  created_launch_uuid=$(create_new_launch ${PROJECT} ${API_TOKEN} ${ZIP_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER} | jq -r .id)

  #stopping created launch
  stopped_launch=$(stop_launch ${PROJECT} ${API_TOKEN} ${created_launch_uuid})

  #creating test-suite
  test_suite=$(create_test_suite ${PROJECT} ${API_TOKEN} ${created_launch_uuid} ${TEST_PLAN_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER})
fi

