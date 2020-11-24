#!/bin/bash

# If we're not running on the staging Jenkins, do nothing.
if [ "$JENKINS_MASTER_URL" != "https://baseos-stg-jenkins.rhev-ci-vms.eng.rdu2.redhat.com" ]; then
    exit 0
fi

CITOOL_EXTRA_DOCKER_ARGS="--entrypoint /bin/bash" /var/lib/jenkins/citool-container.sh -c "cd /WORKDIR && /WORKDIR/reportportal-import-results.sh"