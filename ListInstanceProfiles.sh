#!/bin/bash
aws_account_name="$1"
POLICY_PATH="./Accounts/policies"
file_exists() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}
get_aws_account_id=$(aws sts get-caller-identity --query Account --output text)
get_aws_region=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
echo -e "AWS ACCOUNT ID:- $get_aws_account_id"
echo -e "AWS_REGION :- $get_aws_region"
get_instance_ids=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' | sed 's/[][]//g')
get_instance_ids=$(echo $get_instance_ids | tr -d ' ')
IFS="," read -ra instance_ids <<< "$get_instance_ids"
if [[ -z ${instance_ids} ]]
then
  echo -e "Instance Doesn't Exists"
  echo "$aws_account_name,X,X,X" >> "${aws_account_name}.csv"
  echo "" >> "${aws_account_name}.csv"
else
  for instance_id in "${instance_ids[@]}"
  do
    instance_id=$(echo $instance_id | sed 's/"//g')
    echo -e "InstanceID:- $instance_id"
    get_instance_profile=$(aws ec2 describe-instances --query "Reservations[*].Instances[?InstanceId =='${instance_id}'].IamInstanceProfile.Arn" --output text)
    instance_name=$(aws ec2 describe-instances --query "Reservations[*].Instances[?InstanceId =='${instance_id}'].Tags[]" | jq -r '.[][] | select(.Key == "Name") | .Value')
    echo "Instance Name $instance_name"
    if [[ -z ${get_instance_profile} ]]
    then
      echo -e "Role Doesn't Exists for $instance_name"
      echo -n "$get_aws_account_id,$get_aws_region,$aws_account_name,$instance_name,'X','X'" >> "${aws_account_name}.csv"
      echo "" >> "${aws_account_name}.csv"
      continue
    else
      echo -e "Role Exists"
      instance_profile_role="${get_instance_profile##*/}"
      get_role_name=$(aws iam get-instance-profile --instance-profile-name $instance_profile_role --query 'InstanceProfile.Roles[*].RoleName' --output text)
      get_managed_policies=$(aws iam list-attached-role-policies --role-name $get_role_name --query 'AttachedPolicies[*].PolicyName' --output text)
      echo -e "Managed Policy :- $get_managed_policies"
      if [[ -z ${get_managed_policies} ]]
      then
        echo -e "No Managed Policy"
      else
        read -ra manged_policies <<< "$get_managed_policies"
        for managed_p in "${manged_policies[@]}"
        do
          get_policy_arn=$(aws iam list-policies --query "Policies[?PolicyName=='${managed_p}'].Arn" --output text)
          get_policy_document=$(aws iam get-policy-version --policy-arn $get_policy_arn --version-id v1 --output json)
          if file_exists "${POLICY_PATH}/${aws_account_name}_${managed_p}.json"; then
              echo -e "Policy JSON file ${managed_p}.json already exists. Skipping..."
          else
              echo "$get_policy_document" >> "${POLICY_PATH}/${aws_account_name}_${managed_p}.json"
              echo -e "Policy JSON for $managed_p written to ${POLICY_PATH}/${aws_account_name}_${managed_p}.json"
          fi
        done
        fi
      get_customer_policies=$(aws iam list-role-policies --role-name $get_role_name --query 'PolicyNames' --output text)
      echo -e "Customer Managed Policy :- $get_customer_policies"
      if [[ -z ${get_customer_policies} ]]
      then
        echo -e "No Customer Inline Policy"
      else
        read -ra inline_policies <<< "$get_customer_policies"
        for inline_p in "${inline_policies[@]}"
        do
          get_policy_document=$(aws iam get-role-policy --role-name $get_role_name --policy-name $inline_p --output json)
          if file_exists "${POLICY_PATH}/${aws_account_name}_${inline_p}.json"; then
              echo -e "Policy JSON file ${inline_p}.json already exists. Skipping..."
          else
              echo "$get_policy_document" >> "${POLICY_PATH}/${aws_account_name}_${inline_p}.json"
              echo -e "Policy JSON for $inline_p written to ${POLICY_PATH}/${aws_account_name}_${inline_p}.json"
          fi
        done
        fi
      get_policies=$(echo "${get_managed_policies} ${get_customer_policies}")
      if [[ -z ${get_policies} ]]
      then
        echo -e "No Policy attached to Role:- $get_role_name"
        echo -n "$get_aws_account_id,$get_aws_region,$aws_account_name,$instance_name,$instance_profile_role,X" >> "${aws_account_name}.csv"
        echo "" >> "${aws_account_name}.csv"
      else
        echo "Policy :- $get_policies"
        read -ra policies <<< "$get_policies"
        for policy in "${policies[@]}"
        do
          echo -e "Writing CSV"
          echo -e "Policy name:- $policy"
          echo -n "$get_aws_account_id,$get_aws_region,$aws_account_name,$instance_name,$instance_profile_role,$policy" >> "${aws_account_name}.csv"
          echo "" >> "${aws_account_name}.csv"
        done
      fi
    fi
  done
fi

