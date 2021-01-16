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
REPORT_LOG="report.log"

echo " topic RUNNING - starting script for task $TASK_ID and plan $TEST_PLAN_NAME" >> $TASK_ID/$REPORT_LOG
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $TASK_ID/$REPORT_LOG

# resolve correct project
PROJECT=$(get_project ${ZIP_NAME})

echo " running_script: project - $PROJECT" >> $TASK_ID/$REPORT_LOG

LAUNCH_NAME=$NVR

if [ $SCRATCH == "true" ]
then
  LAUNCH_NAME=$NVR\(scratch\)
fi

echo " running_script: component - $ZIP_NAME" >> $TASK_ID/$REPORT_LOG
echo " running_script: launch name - $LAUNCH_NAME" >> $TASK_ID/$REPORT_LOG

# import data with appropriate tokens
UI_TOKEN=$(get_ui_token ${USERNAME} ${PASSWORD})

API_TOKEN=$(get_api_token ${UI_TOKEN})
echo $API_TOKEN

#find launch with same task-id
FOUND=$(get_launch_by_task_id ${PROJECT} ${API_TOKEN} ${TASK_ID})
echo $FOUND
number_of_found=$(echo $FOUND | jq '.page.totalElements' --raw-output)
found_launch_id=$(echo $FOUND | jq '.content[0].id' --raw-output)
found_launch_uuid=$(echo $FOUND | jq '.content[0].uuid' --raw-output)

echo " running_script: found - $FOUND" >> $TASK_ID/$REPORT_LOG

#found_launches
if [ $number_of_found != 0 ]
then
  #creating test-suite
  test_suite=$(create_test_suite ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${TEST_PLAN_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER})
  echo " running_script: created test_suite - $test_suite" >> $TASK_ID/$REPORT_LOG
else
  #creating new launch
  created_launch_uuid=$(create_new_launch ${PROJECT} ${API_TOKEN} ${LAUNCH_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER} ${ZIP_NAME} ${TEST_PLAN_NAME} | jq -r .id)
  echo " running_script: created launch - $created_launch_uuid" >> $TASK_ID/$REPORT_LOG

  #stopping created launch
  stopped_launch=$(stop_launch ${PROJECT} ${API_TOKEN} ${created_launch_uuid})
  echo " running_script: stopped launch - $stopped_launch" >> $TASK_ID/$REPORT_LOG

  #creating test-suite
  test_suite=$(create_test_suite ${PROJECT} ${API_TOKEN} ${created_launch_uuid} ${TEST_PLAN_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER})
  echo " running_script: created test_suite - $test_suite" >> $TASK_ID/$REPORT_LOG
fi
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $TASK_ID/$REPORT_LOG

