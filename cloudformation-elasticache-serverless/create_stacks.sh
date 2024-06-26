#!/bin/bash

cd $(dirname $0)

# 各システム名定義
SYSTEM_NAME_TEMPLATE=template

# 各環境名定義
ENV_TYPE_DEV=dev
ENV_TYPE_STG=stg
ENV_TYPE_PROD=prod

# 各リージョン名定義
REGION_NAME_TOKYO=tokyo
REGION_NAME_OSAKA=osaka
REGION_NAME_VIRGINIA=virginia

create_stack() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    SERVICE_NAME=$4

    aws cloudformation create-stack \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --template-body file://./templates/${SERVICE_NAME}/${SERVICE_NAME}.yml \
        --cli-input-json file://./templates/${SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    aws cloudformation wait stack-create-complete \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}
}

get_private_key() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3

    key_pair_name=$(jq -r '.Parameters[] | select(.ParameterKey == "KeyName").ParameterValue' "./templates/keypair/${ENV_TYPE}-${REGION_NAME}-parameters.json")

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
        --query "Account" \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} \
        --output text)

    KEY_PAIR_ID=$(aws ec2 describe-key-pairs \
        --filters Name=key-name,Values=${key_pair_name} \
        --query KeyPairs[*].KeyPairId \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} \
        --output text)

    aws ssm get-parameter \
        --name /ec2/keypair/${KEY_PAIR_ID} \
        --with-decryption \
        --query Parameter.Value \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME} \
        --output text > ${key_pair_name}.pem

    chmod 600 ${key_pair_name}.pem

}

replace_parameter_json() {
    ENV_TYPE=$1
    REGION_NAME=$2
    SOURCE_REPLACE_KEY_NAME=$3
    SOURCE_SERVICE_NAME=$4
    TARGET_REPLACE_KEY_NAME=$5
    TARGET_SERVICE_NAME=$6

    replace_value=$(jq -r '.Parameters[] | select(.ParameterKey == "'${SOURCE_REPLACE_KEY_NAME}'").ParameterValue' "./templates/${SOURCE_SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json")

    jq --indent 4 '.Parameters[] |= if .ParameterKey == "'${TARGET_REPLACE_KEY_NAME}'" then .ParameterValue = "'${replace_value}'" else . end' \
        ./templates/${TARGET_SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json > \
        tmp.json && mv tmp.json ./templates/${TARGET_SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json

}

#####################################
# 構築対象リソース
#####################################
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_VIRGINIA} iam-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} kms
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network-flowlog
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} securitygroup-elasticache
# create_stack ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} elasticache

exit 0
