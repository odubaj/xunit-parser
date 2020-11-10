#!/bin/bash

# curl -X POST "http://localhost:8080/api/v1/arch/launch/import" 
# -H  "accept: */*" -H  "Content-Type: multipart/form-data" 
# -H  "Authorization: bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MDQ4NDgwMzcsInVzZXJfbmFtZSI6InN1cGVyYWRtaW4iLCJhdXRob3JpdGllcyI6WyJST0xFX0FETUlOSVNUUkFUT1IiXSwianRpIjoiNjM0MmZmZjUtZDk0YS00YmIxLWFiYjEtNmM5ZTg3YzY1NTRmIiwiY2xpZW50X2lkIjoidWkiLCJzY29wZSI6WyJ1aSJdfQ.bKehEviw-JXK-pfAocLETlz2Ww-ahq7Uooiybd16gEE" 
# -d {"file":{}}


function import_xunit() {
    local project=$1
    local api_token=$2
    local file=$3

    echo $(curl --header "Content-Type: multipart/form-data" \
        --header "Authorization: Bearer $api_token" \
        --request POST \
        --form "file=@./$file" \
        http://reportportal.infrastructure.testing-farm.io/api/v1/${project}/launch/import)
}