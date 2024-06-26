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

# 変更セット 作成
exec_change_set() {
    SYSTEM_NAME=$1
    ENV_TYPE=$2
    REGION_NAME=$3
    SERVICE_NAME=$4

    echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
    echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを作成します。"

    # 変更セット 作成
    aws cloudformation create-change-set \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
        --template-body file://./templates/${SERVICE_NAME}/${SERVICE_NAME}.yml \
        --cli-input-json file://./templates/${SERVICE_NAME}/${ENV_TYPE}-${REGION_NAME}-parameters.json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    # ChangeSetCreateComplete 待機
    aws cloudformation wait change-set-create-complete \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

    # 変更セット Status 取得
    CHANGE_SET_STATUS=$(aws cloudformation describe-change-set \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
        --query 'Status' \
        --output text \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    # 変更セット作成失敗時処理
    if [ "$CHANGE_SET_STATUS" = "FAILED" ]; then
        echo "変更セットの作成に失敗しました。"
        echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを削除します。"

        # 変更セット 削除
        aws cloudformation delete-change-set \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを削除しました。"
        return 1
    fi

    # 変更セット 詳細表示
    DESCRIBE_CHANGE_SET=$(aws cloudformation describe-change-set \
        --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
        --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
        --query 'Changes[*].[ResourceChange.Action, ResourceChange.LogicalResourceId, ResourceChange.PhysicalResourceId, ResourceChange.ResourceType, ResourceChange.Replacement]' \
        --output json \
        --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME})

    echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set"
    echo "$DESCRIBE_CHANGE_SET" | jq -r '.[] | "--------------------------------------------------\nアクション: \(.[0])\n論理ID: \(.[1])\n物理ID: \(.[2])\nリソースタイプ: \(.[3])\n置換: \(.[4])"'
    echo "--------------------------------------------------"

    # 変更セット実行確認処理
    read -p "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを実行してよろしいですか？ (Y/n) " yn

    case ${yn} in
    [yY])
        echo "変更セットを実行します。"

        # 変更セット 実行
        aws cloudformation execute-change-set \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        # StackUpdateComplete 待機
        aws cloudformation wait stack-update-complete \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        echo "${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}のUpdateが完了しました。"
        ;;
    *)
        # 中止
        echo "変更セットの実行を中止しました。"

        # 変更セット 削除
        aws cloudformation delete-change-set \
            --stack-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME} \
            --change-set-name ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-set \
            --profile ${SYSTEM_NAME}-${ENV_TYPE}-${REGION_NAME}

        echo "変更セット: ${SYSTEM_NAME}-${ENV_TYPE}-${SERVICE_NAME}-change-setを削除しました。"
        ;;
    esac

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
# 変更対象リソース
#####################################
# replace_parameter_json ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} KeyName keypair KeyName ec2-bastion
# replace_parameter_json ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} KeyName keypair KeyName launchtemplate-windows
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_VIRGINIA} iam
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_VIRGINIA} iam-flowlog
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} kms
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} keypair
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} network-flowlog
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} securitygroup
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} ec2-bastion
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} alb
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} launchtemplate-windows
# exec_change_set ${SYSTEM_NAME_TEMPLATE} ${ENV_TYPE_DEV} ${REGION_NAME_TOKYO} asg

exit 0
