#!/bin/bash
set -e
export de_project="de-c2w1lab2"
export AWS_DEFAULT_REGION="us-east-1"
## Getting instance_public_ip and instance_id
export instance_public_ip=$(ec2-metadata --public-ip|grep -oE '[0-9]+(\.[0-9]+)+')
export instance_id=$(aws ec2 describe-instances --query "Reservations[].Instances[?PublicIpAddress=='$instance_public_ip'].InstanceId" --output text)

REQUIREMENTS_FILE="$(pwd)/scripts/requirements.txt"

## Associating instance profile
inst_prof=$(aws ec2 describe-iam-instance-profile-associations --query 'IamInstanceProfileAssociations[?contains(InstanceId, `'$instance_id'`) == `true`].AssociationId' --output text)
echo "===> ASSOCIATING NEW INSTANCE PROFILE TO LAB EC2 INSTANCE <===
$(if [ -z $inst_prof ]
then
    echo "    
    associating LabEC2InstanceProfile... ... ...    
    "
    aws ec2 associate-iam-instance-profile --iam-instance-profile Name=LabEC2InstanceProfile --instance-id $instance_id
else
    echo "    
    replacing:" $inst_prof "by LabEC2InstanceProfile
    "
    aws ec2 replace-iam-instance-profile-association --iam-instance-profile Name=LabEC2InstanceProfile --association-id $(aws ec2 describe-iam-instance-profile-associations --query 'IamInstanceProfileAssociations[?contains(InstanceId, `'$instance_id'`) == `true`].AssociationId' --output text)

fi )
===> VERYFYING ASSOCIATION <===
$(aws ec2 describe-iam-instance-profile-associations  --filters 'Name=instance-id,Values='$instance_id'' --query 'IamInstanceProfileAssociations[*].IamInstanceProfile.Arn' --output text > /tmp/msg.txt)
$(cat /tmp/msg.txt)
"

##DISABLING AUTOMATIC CREDENTIALS MANAGEMENT (RUNNING WITH LATEST CLI!!)
echo "============================> DISABLING AUTOMATIC CREDENTIALS MANAGEMENT <=============================================================================
$(/usr/local/bin/aws cloud9 update-environment --environment-id $C9_PID --managed-credentials-action DISABLE)
"


## Getting security_group_id
export security_group_id=$(aws ec2 describe-instances --output table --query 'Reservations[*].Instances[*].NetworkInterfaces[*].Groups[*].GroupId' --region $AWS_DEFAULT_REGION --instance-ids $instance_id --output text)

## Adding ingress rule to pot 8888 and all sources
export sg_modification_status=$(aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 8888 --cidr 0.0.0.0/0 --query 'Return' --output text)

echo "Security group modified properly: $sg_modification_status"

# Define some environment variables used in the lab
echo "export CLI_PRODUCER_PATH=$HOME/environment/src/cli/" >> $HOME/.bashrc
echo "export CLI_CONSUMER_PATH=$HOME/environment/src/cli/" >> $HOME/.bashrc
echo "export CONSUMER_PATH=$HOME/environment/src/etl/" >> $HOME/.bashrc
echo "export AWS_DEFAULT_REGION=us-east-1" >> $HOME/.bashrc

source $HOME/.bashrc

## Install Jupyter Lab
python3 -m venv jupyterlab-venv
source jupyterlab-venv/bin/activate
pip install --upgrade pip
pip install -r "$REQUIREMENTS_FILE"

echo "Requirements installed successfully"

## Run Jupyter Lab in the background and redirect output to a file
nohup jupyter lab --ip 0.0.0.0 --port 8888 > jupyter_output.log 2>&1 &

## Wait for a moment to ensure Jupyter Lab starts
sleep 25

## Extract the URL from the output file
jupyter_url_local=$(grep -oP 'http://127.0.0.1:\d+/lab\?token=[a-f0-9]+' jupyter_output.log | head -1)

## Get the EC2 instance's public DNS name
ec2_dns=$(ec2-metadata --public-hostname|grep -o ec2-.*)

## Replace the DNS in the URL
jupyter_url=$(echo "$jupyter_url_local" | sed "s/127.0.0.1/${ec2_dns}/")

# Print the updated URL
echo "Jupyter is running at: $jupyter_url" >> jupyter_output.log
echo "Jupyter is running at: $jupyter_url"