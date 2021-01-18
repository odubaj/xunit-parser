#!/bin/bash

# script handling valid error messages from UMB

source functions.sh

USERNAME=$1
PASSWORD=$2
ZIP_NAME=$3
SCRATCH=$4
NVR=$5
TASK_ID=$6
TEST_PLAN_NAME=$7
ISSUER=$8
log1=$9
log2=${10}
log3=${11}
REPORT_LOG="report.log"

echo " topic ERROR - starting script for task $TASK_ID and plan $TEST_PLAN_NAME" >> $TASK_ID/$REPORT_LOG
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $TASK_ID/$REPORT_LOG

# resolve correct project
PROJECT=$(get_project ${ZIP_NAME})

echo " err_script: project - $PROJECT" >> $TASK_ID/$REPORT_LOG

if [ $SCRATCH == "true" ]
then
  ZIP_NAME=$ZIP_NAME\(scratch\)
fi

LAUNCH_NAME=$NVR

if [ $SCRATCH == "true" ]
then
  LAUNCH_NAME=$NVR\(scratch\)
fi

echo " err_script: component - $ZIP_NAME" >> $TASK_ID/$REPORT_LOG

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

echo " err_script: found - $FOUND" >> $TASK_ID/$REPORT_LOG

if [ $number_of_found != 0 ]
then
  #find running item to be stopped
  RUNNING_ITEM=$(get_item_by_filter ${PROJECT} ${API_TOKEN} ${TASK_ID} ${TEST_PLAN_NAME} ${found_launch_id})
  echo $RUNNING_ITEM
  number_of_items=$(echo $RUNNING_ITEM | jq '.page.totalElements' --raw-output)
  echo " err_script: running_item - $RUNNING_ITEM" >> $TASK_ID/$REPORT_LOG

  if [ $number_of_items != 0 ]
  then
    item_id=$(echo $RUNNING_ITEM | jq '.content[0].id' --raw-output)
    item_uuid=$(get_item_uuid ${PROJECT} ${API_TOKEN} ${item_id} | jq '.[0].uuid' --raw-output)
    result=$(stop_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid})
    echo $result
    echo " err_script: stopped - $result" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log1})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log2})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log3})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
  else
    #creating test-suite
    test_suite=$(create_test_suite ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${TEST_PLAN_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER})
    echo " error_script: created test_suite - $test_suite" >> $TASK_ID/$REPORT_LOG

    item_uuid=$(echo ${test_suite} | jq '.id' --raw-output)
    result=$(stop_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid})
    echo $result
    echo " err_script: stopped - $result" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log1})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log2})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
    logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${found_launch_uuid} ${item_uuid} ${log3})
    echo $logs
    echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
  fi
else
  #creating new launch
  created_launch_uuid=$(create_new_launch ${PROJECT} ${API_TOKEN} ${LAUNCH_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER} ${ZIP_NAME} ${TEST_PLAN_NAME} | jq -r .id)
  echo " error_script: created launch - $created_launch_uuid" >> $TASK_ID/$REPORT_LOG

  #stopping created launch
  stopped_launch=$(stop_launch ${PROJECT} ${API_TOKEN} ${created_launch_uuid})
  echo " error_script: stopped launch - $stopped_launch" >> $TASK_ID/$REPORT_LOG

  #creating test-suite
  test_suite=$(create_test_suite ${PROJECT} ${API_TOKEN} ${created_launch_uuid} ${TEST_PLAN_NAME} ${SCRATCH} ${NVR} ${TASK_ID} ${ISSUER})
  echo " error_script: created test_suite - $test_suite" >> $TASK_ID/$REPORT_LOG

  item_uuid=$(echo ${test_suite} | jq '.id' --raw-output)
  result=$(stop_error_item ${PROJECT} ${API_TOKEN} ${created_launch_uuid} ${item_uuid})
  echo $result
  echo " err_script: stopped - $result" >> $TASK_ID/$REPORT_LOG
  logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${created_launch_uuid} ${item_uuid} ${log1})
  echo $logs
  echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
  logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${created_launch_uuid} ${item_uuid} ${log2})
  echo $logs
  echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
  logs=$(logs_error_item ${PROJECT} ${API_TOKEN} ${created_launch_uuid} ${item_uuid} ${log3})
  echo $logs
  echo " logs_error_item - $logs" >> $TASK_ID/$REPORT_LOG
fi
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $TASK_ID/$REPORT_LOG