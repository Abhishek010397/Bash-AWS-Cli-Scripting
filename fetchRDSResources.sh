#!/bin/bash
aws_account_name="$1"
directory_name=$2
get_rds_snapshots=()
snapshots=()
get_parameter_groups=$(aws rds describe-db-parameter-groups --query 'DBParameterGroups[?DBParameterGroupFamily==`mysql5.6`|| DBParameterGroupFamily==`mysql5.7`].DBParameterGroupName' --output text)
get_option_groups=$(aws rds describe-option-groups --query "OptionGroupsList[?MajorEngineVersion=='5.7' || MajorEngineVersion=='5.6'].OptionGroupName" --output text)
## CHECK RDS SNAPSHOT
read -ra option_groups <<< "$get_option_groups"f
for option in "${option_groups[@]}"
do
 if [[ $option != "default:mysql-5-7" && $option != "default:mysql-5-6" && $option != "default:aurora-5-6" && $option != "default:aurora-mysql-5-7" ]]
 then
   snapshots=$(aws rds describe-db-snapshots --query "DBSnapshots[?OptionGroupName =='${option}'].DBSnapshotIdentifier" --output text)
   read -ra snapshots <<< "$snapshots"
   for snap in "${snapshots[@]}"
   do
     echo $snap
     get_rds_snapshots+=$(echo $snap",")
  done
fi
done
read -ra rds_snapshots <<< "$get_rds_snapshots"
## CHECK PARAMETER GROUP$
read -ra parameter_groups <<< "$get_parameter_groups"
for parameter_group_family in "${parameter_groups[@]}"
do
  if [[ $parameter_group_family != "default.mysql5.7" && $parameter_group_family != "default.mysql5.6" ]]
  then
    parameters+="$parameter_group_family"
  fi
done

## CHECK OPTION GROUPS
read -ra option_groups <<< "$get_option_groups"
for option_group_name in "${option_groups[@]}"
do
  if [[ $option_group_name != "default:mysql-5-7" && $option_group_name != "default:mysql-5-6" && $option_group_name != "default:aurora-5-6" && $option_group_name != "default:aurora-mysql-5-7" ]]
  then
	  options+=("$option_group_name")
  fi
done

## CHECK BACKUP VAULT JOB FOR RDS SNAPSHOTS
min_length=$(( ${#parameters[@]} < ${#options[@]} ? ${#options[@]} : ${#parameters[@]} ))

min_length=$(( $min_length < ${#snapshots[@]} ? ${#rds_snapshots[@]} : $min_length ))

echo "AWS_ACCOUNT_NAME,PARAMETER_GROUP_NAME,OPTION_GROUP,OPTION_GROUP_NAME ---> SNAPSHOTS" > "${aws_account_name}.csv"  # Adding headers

for ((i = 0; i < min_length; i++)); do
      if [ -n "${parameters[$i]}" ] || [ -n "${options[$i]}" ] || [ -n "${rds_snapshots[$i]}" ]; then
	      echo -n "${aws_account_name},${paramaters[$i]:-null},${options[$i]:-null},${rds_snapshots[$i]:-null}" >> "${aws_account_name}.csv"
        echo "" >> "${aws_account_name}.csv"
      fi
done

echo "CSV file '${aws_account_name}.csv' created successfully.\n"
exit
