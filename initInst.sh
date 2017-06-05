#!/bin/bash

# ===========================
# Author: Cedric Bhihe
# Email: cedric.bhihe@gamil.com
# Date: 2017.05.31
# ===========================

# Launch specific AWS instance from pre-built AMI with custom security group, 
# connect to it and discover instance-ID and PublicIP
# Script requires bash v4+ or array-capable shell (zsh) for array support

instNbr=1
instType="t2.micro"
amiID="ami-d4b9b5ad"  
sgID="sg-1187dd6a"
# keyFile="/home/ckb/Study/UPC/Subjects/DS_decentralized-systems/Project/upcfib_ds.pem"
keyFile="upcfib_ds.pem"
workDIR="$HOME/Study/UPC/Subjects/DS_decentralized-systems/Project/"

cd "$workDIR"

# Set credentials and settings locally if necessary
printf "AWS EC2 instance launch from an AMI.\n==================================\n\n"

read -p  " - Is package 'awscli' installed ? (y|n): " resp1

case "$resp1" in
	[nN] | [n|N][O|o] )
		printf "Please install 'awscli' first. Documentation is at:\n";
		printf "https://docs.aws.amazon.com/cli/latest/userguide/installing.html.\n";
		printf "Script will exit now.\n"; exit 2
		;;
	[yY] | [yY][Ee][Ss] )
		aws --version;
		read -p " - Is AWS CLI configured to access resources on AWS ? (y|n): " resp2;
		case $resp2 in
			[nN] | [n|N][O|o] )
				printf "Have your AWS Access Key ID and Secret Access Key ready...\n";
				aws configure;
				printf "\nProceed to launch instance ...\n"
				;;
			[yY] | [yY][Ee][Ss] )
				printf "Proceed to launch instance ...\n"
				;;
			*)
				printf "Answer (\"%s\") not understood. Start again.\n" "$resp2";
				printf "Script will exit now.\n"; exit 3
				;;
		esac
		;;
	* )
		printf "Answer (\"%s\") not understood. Start again.\n" "$resp1";
		printf "Script will exit now.\n"; exit 3
		;;
esac

# Launch procedure
printf "\nVerify that relevant security group(s), key pair(s) and AMI(s)\n"
printf "already exist for your account. If not type CTRL+c to abort.\n"

#+ Assume that relevant security group(s), key pair(s) and AMI(s) already exist.
instID=""
instID="$(aws ec2 run-instances --image-id "$amiID" --security-group-ids "$sgID" --count "$instNbr" --instance-type "$instType" --key-name "$keyFile" --query 'Instances[0].InstanceId')"

time1="$(/bin/date +%s)"

printf "Launching %s instance(s) of type %s on AWS..." "$instNbr" "$instType"

# Discover launched instance's public IP 
instPubIP="$(aws ec2 describe-instances --instance-ids "$instID" --query 'Reservations[0].Instances[0].PublicIpAddress')"

printf "\nInstance with ID %s was launched.\n" "$instID" 
printf "Instance public IP: %s\n" "$instPubIP"

# Discover launched instance's status

printf "Instance initialization (pending) ..."

instStat=""
waitcnt=0

while [ ! "$instStat" = "running" ]; do
	instStat="$(aws ec2 describe-instance-status --instance-ids "$instID" | \
	awk '/INSTANCESTATE/ {print $3}')"
	if [ "$((waitcnt%40))" -eq  "0" ]; then
		printf "\n="
	else
		printf "="
	fi
	waitcnt="$((waitcnt+1))"
done

time2="$(/bin/date +%s)"
printf "\n Instance RUNNING !\nTime elapsed till availability: %d\n" "$((time2-time1))"

# Discover instance reachability

declare -a instReach;
waitcnt=0
printf " ... building communication ...\n" 
while [ ! "x${instReach[0]}" = "xpassed" -o ! "x${instReach[1]}" = "xpassed" ]; do
	instReach=( $(aws ec2 describe-instance-status --instance-ids "$instID" | awk '/reachability/ {print $3}') )
	if [ "$((waitcnt%40))" -eq  "0" ]; then
		printf "\n="
	else
		printf "="
	fi
	waitcnt="$((waitcnt+1))"
done

time3="$(/bin/date +%s)"
printf " Instance REACHABLE !\nTime elapsed till reachability: %d\n" \
	"$((time3-time2))"

# SSH connect to instance (open instance shell in tty) 

printf "\n SSH connect to instance, open instance shell in tty\n"

ssh -i "$keyFile" ubuntu@"$instPubIP"

exit 0
