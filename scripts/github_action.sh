#!/bin/bash

OWNER="$1"
REPO_NAME="$2"
WORKFLOW="$3"
INPUTS="$4"
USER="$5"
PWD="$6"
BRANCH="$7"

if [ "$#" -eq 5 ]; then
  # use cURL with a Personal Access Token
  echo "Using USER as personal access token for the GitHub API"
  PARAMS=(-H "Authorization: Bearer $USER" -H "Accept: application/vnd.github.v3+json")

elif [ "$#" -ge 6 ]; then
  # use basic auth with cUrl
  echo "Using USER/PWD authentication for the GitHub API"
  PARAMS=(-u "$USER":"$PWD" -H "Accept: application/vnd.github.v3+json")

else
  echo "Usage: github_action.sh OWNER REPO_NAME WORKFLOW INPUTS USER [PWD]"
  echo "OWNER     = the owner/org of the github repo"
  echo "REPO_NAME = the name of the github repo"
  echo "WORKFLOW  = the name of the workflow file to run, or its ID"
  echo "INPUTS    = json representation of the workflow input"
  echo "USER      = the username to use for authentication against the GitHub API, or an API token"
  echo "PWD       = the password of USER. if not specified, USER will be interpreted as token"
  echo "BRANCH"   = the branch on which to execute the action. Defaults to "main"
  exit 1
fi

REPO="$OWNER/$REPO_NAME"
WORKFLOW_PATH="$REPO/actions/workflows/$WORKFLOW"

# run actions on "main" by default
if [ -z "${BRANCH}" ]; then
  BRANCH="main"
fi

if [ -z "${INPUTS}" ]; then
  TRIGGER_BODY="{\"ref\": \"${BRANCH}\"}"
else
  TRIGGER_BODY="{\"ref\": \"${BRANCH}\", \"inputs\": ${INPUTS}}"
fi

echo "$WORKFLOW_PATH :: $(date) :: Trigger the workflow with ${TRIGGER_BODY}"
STATUSCODE=$(curl --location --request POST --write-out "%{http_code}" "https://api.github.com/repos/${WORKFLOW_PATH}/dispatches" \
  "${PARAMS[@]}" \
  --data-raw "${TRIGGER_BODY}")

if [ "$STATUSCODE" != 204 ]; then
  echo "$WORKFLOW_PATH :: $(date) :: Cannot trigger workflow. Response code: $STATUSCODE"
  exit 1
fi

# this is not working anymore, details: https://github.com/orgs/community/discussions/53266
# numRuns=0
# echo "$WORKFLOW_PATH :: $(date) :: Waiting for workflow to start"
# while [ "$numRuns" -le "0" ]; do
#   sleep 3
#   # fetch the latest run triggered by a workflow_dispatch event
#   runs=$(curl --fail -sSl "${PARAMS[@]}" -X GET "https://api.github.com/repos/${WORKFLOW_PATH}/runs?event=workflow_dispatch&status=in_progress")
#   numRuns=$(echo "$runs" | jq -r '.total_count')
#   echo "$WORKFLOW_PATH :: $(date) :: found $numRuns runs"
# done

status=
echo "$WORKFLOW_PATH :: $(date) :: Waiting for workflow to start"
while [ "$status" != "in_progress" ]; do
  sleep 5
  # fetch the latest run triggered by a workflow_dispatch event
  runs=$(curl --fail -sSl "${PARAMS[@]}" -X GET "https://api.github.com/repos/${WORKFLOW_PATH}/runs?event=workflow_dispatch&per_page=1")
  status=$(echo "$runs" | jq -r '.workflow_runs[0].status')
  echo "$WORKFLOW_PATH :: $(date) :: status $status"
done

# contains the ID of the latest/most recent run
RUN_ID=$(echo "$runs" | jq -r '.workflow_runs[0].id')

echo "$WORKFLOW_PATH :: $(date) :: Waiting for run $RUN_ID to complete"
while [ "$status" != "completed" ]; do
  json=$(curl --fail -sSl "${PARAMS[@]}" -X GET "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}")
  status=$(echo "$json" | jq -r '.status')
  conclusion=$(echo "$json" | jq -r '.conclusion')
  echo "$WORKFLOW_PATH :: $(date) :: Run $RUN_ID is $status"
  if [ "$status" != "completed" ]; then
    sleep 30 # sleep for 30 seconds before we check again, lets keep API requests low
  fi
done

echo "$WORKFLOW_PATH :: $(date) :: Run completed, conclusion: $conclusion"

if [ "$conclusion" != "success" ]; then
  exit 1
fi
