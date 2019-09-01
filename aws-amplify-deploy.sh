#!/usr/bin/env bash
set -e

# based on https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
PARAMS=""
while (("$#")); do
    case "$1" in
    -a | --app-id)
        APP_ID=$2
        shift 2
        ;;
    -b | --branch-name)
        BRANCH_NAME=$2
        shift 2
        ;;
    -d | --dist-dir)
        DIST_DIR=$2
        shift 2
        ;;
    -s | --bucket-name)
        S3_BUCKET_NAME=$2
        shift 2
        ;;
    -p | --basic-auth)
        BASIC_AUTH=$2
        shift 2
        ;;
    -* | --*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        exit 1
        ;;
    *) # preserve positional arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    --) # end argument parsing
        shift
        break
        ;;
    esac
done
# set positional arguments in their proper place
eval set -- "$PARAMS"

function printerr() { printf "%s\n" "$*" >&2; }

function check-mandatory-parameters() {
    local error=0
    if [[ -z ${APP_ID} ]]; then
        printerr "Mandatory paramter or environment variable for the app id is missing."
        error=1
    fi
    if [[ -z ${BRANCH_NAME} ]]; then
        printerr "Mandatory paramter or environment variable for the branch name is missing."
        error=1
    fi
    if [[ -z ${S3_BUCKET_NAME} ]]; then
        printerr "Mandatory paramter or environment variable for the s3 bucket is missing."
        error=1
    fi
    if [[ -z ${DIST_DIR} ]]; then
        printerr "Mandatory paramter or environment variable for the distribution dir is missing."
        error=1
    fi

    if [[ ${error} > 0 ]]; then
        exit 1
    fi
}

function wait-for-deployment() {
    local jobId=$1
    local timeout=300
    while [[ ! $jobStatus == 'SUCCEED' || $timer > $timeout ]]; do
        local job=$(aws amplify get-job --branch-name ${BRANCH_NAME} --app-id ${APP_ID} --job-id ${jobId})
        local jobStatus=$(echo ${job} | jq -r '.job.summary.status')
        if [[ $((timer % 5)) == 0 ]]; then
            echo Waiting for job current status ${jobStatus}
        fi
        sleep 1
        timer=$((timer + 1))
    done

    curl $(echo ${job} | jq -r '.job.steps[] | select ( .stepName  | contains ( "DEPLOY")) | .logUrl')

}

function create-branch() {
    local bracn_count=$(aws amplify list-branches --app-id ${APP_ID} | jq -r '[.branches[] | select(.branchName | contains("'${BRANCH_NAME}'") )] | length')

    if [[ ${bracn_count} == 0 ]]; then
        echo Creating branch
        aws amplify create-branch --app-id ${APP_ID} --branch-name ${BRANCH_NAME} 2>&1 >/dev/null || true
    fi
}

function basic-auth() {
    local bracn_count=$(aws amplify list-branches --app-id $APP_ID | jq -r '[.branches[] | select(.branchName | contains("'${BRANCH_NAME}'") )] | length')

    if [[ ! -z ${BASIC_AUTH} ]]; then
        aws amplify edit-branch --app-id ${APP_ID} --branch-name ${BRANCH_NAME} --enable-basic-auth --basic-auth-credentials $BASIC_AUTH
    fi
}

function upload-dist() {
    echo Creating zip and uploading to S3 bucket ${S3_BUCKET_NAME}
    _pwd=$(pwd)
    cd ${DIST_DIR}
    rm ${BRANCH_NAME}.zip 2>/dev/null || true
    zip -rq ${BRANCH_NAME}.zip .
    aws s3 cp ${BRANCH_NAME}.zip s3://${S3_BUCKET_NAME}
    cd $_pwd
}

check-mandatory-parameters
create-branch
basic-auth
upload-dist
deployment=$(aws amplify start-deployment --app-id ${APP_ID} --branch-name ${BRANCH_NAME} --source-url s3://${S3_BUCKET_NAME}/${BRANCH_NAME}.zip)
wait-for-deployment $(echo ${deployment} | jq -r '.jobSummary.jobId')

echo ${BRANCH_NAME} deployed to https://${BRANCH_NAME}.${APP_ID}.amplifyapp.com/
