#!/bin/bash

GREEN='\033[0;32m'
NC='\033[0m'
BOLD='\033[1m'
for aws_account_name in $(cat ./accounts.txt)
do
  echo -e "*****************************************************************************"
  echo -e "${BOLD}${GREEN}AWS_ACCOUNT_NAME :- $aws_account_name${NC}"
  aws-vault exec $aws_account_name -- /bin/bash ./ListInstanceProfiles.sh $aws_account_name --duration=1h
done

output_file="./Accounts/accounts.csv"
echo "AWS_ACCOUNT_ID,AWS_REGION,AWS_ACCOUNT_NAME,InstanceName,InstanceProfile,AttachedPolicy" >> "${output_file}"
for file in *.csv
do
    cat ${file} >> "$output_file"
    echo "" >> "$output_file"
#    rm -f "/opt/"${file}
done

echo "CSV files merged into '$output_file'."