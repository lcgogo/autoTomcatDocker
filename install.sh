#!/bin/sh
# This is the install script of atnd.sh
# It will do followed steps:
# 0. Copy atnd.sh to /usr/local/atnd
# 1. Register and enable a service: atnd.service at /usr/lib/systemd/system
# 2. Add CONSTANT to atnd.conf according to your input
#
# mvn test
# echo $BUILD_NUMBER > target/BUILD_NUMBER.txt
#

#############
# Functions #
#############
######################################
# function Input_to_Constant
#
# Description
# Used to get 4 CONSTANT: WAR_FILE_NAME WAR_URL ZIP_FILE_NAME ZIP_URL 
# from screen input
#
# Input
# $1 = fileType #should be war or zip
# $2 = inputUrl
# 
# Return code
# 0 success
# 1 need reinput
# 2 error
function Input_to_Constant(){
  local fileType=$1
  local inputUrl=$2
  local fileName=""
  local fileUrl=""
  local fileSuffix=""

  echo -e Please input the location of "\033[32;49;1m $fileType \033[39;49;0m"  file:
  echo \(For example: http://example.com/demo.$fileType or /var/local/atnd/demo.$fileType\)
  if [ -z $inputUrl ];then
    read inputUrl
  fi
  fileName=`echo $inputUrl | awk -F "/" '{print $NF}'`
  fileUrl=`echo ${inputUrl:0:-${#fileName}}`
  fileSuffix=`echo ${fileName:(-3)}`
    
  if [ $fileSuffix != $fileType ];then
    echo Error input with wrong file type which should be end with $fileType.
    echo -e Your input is : "\033[31;49;1m $inputUrl \033[39;49;0m"
    return 1
  fi
    
  if [ $fileType = war ];then 
    WAR_FILE_NAME=\"$fileName\"
    WAR_URL=\"$fileUrl\"
    return 0
  elif [ $fileType = zip ];then
    ZIP_FILE_NAME=\"$fileName\"
    ZIP_URL=\"$fileUrl\"
    return 0
  else
    echo Error input of function Input_to_Constant should be war or zip.
    return 2
  fi
}
###############################

########################################
# function Create_Config
# 
# Description
# Add 4 CONSTANT: WAR_FILE_NAME WAR_URL ZIP_FILE_NAME ZIP_URL to a config file $configFullPath
# Return code
# 0 Create config correctly 
#
function Create_Config(){
  local warInputResult=""
  local zipInputResult=""
  if [ -e $configFullPath ];then
    echo The $configFullPath is existed. Exit without any change.
    exit 1
  fi
  Input_to_Constant war
  warInputResult=$?
  while [[ $warInputResult -eq 1 || $warInputResult -eq 2 ]]
  do
    Input_to_Constant war
    warInputResult=$?
  done
  
  Input_to_Constant zip
  zipInputResult=$?
  while [[ $zipInputResult -eq 1 || $zipInputResult -eq 2 ]]
  do
    Input_to_Constant zip
    zipInputResult=$?
  done
  
  if [ ! -e $configFullPath ];then
    touch $configFullPath
    echo WAR_FILE_NAME=$WAR_FILE_NAME > $configFullPath
    echo WAR_URL=$WAR_URL >> $configFullPath
    echo ZIP_FILE_NAME=$ZIP_FILE_NAME >> $configFullPath
    echo ZIP_URL=$ZIP_URL >> $configFullPath
  fi
}
############################

###############################################
# function Confirm_Config
# 
# Description
# Confirm the config file if needed.
#
# Return code
# 0 Confirm OK
# 1 Need re-confirm
# 2 Need re-create config
function Confirm_Config(){
  if [ ! -e $configFullPath ];then
    echo The $configFullPath is not existed. Exit without any change.
    return 1
  fi
  echo Your input is below, please confirm again
  echo "#############"
  cat $configFullPath
  echo "#############"
  echo -en "Is this config right? Y(y)/N(n): "
  read choice
  case $choice in
    Y|y|yes|Yes) echo Accept and continue.
         echo Your config is saved at $configFullPath.
         echo You can run this script again to re-config.
         return 0
    ;;
    N|n|no|No) echo Please input the file location again.
         rm -f $configFullPath
         return 2
    ;;
    *) echo Invalid input. Please input Y or N. Your input is $choice.
      # echo Exit now without any changes. You can run this script again if needed.
       return 1
    ;;
  esac
}
################################

########
# Main #
########
echo This script is used to install atnd.sh as a system service.

runFile=atnd.sh
runFolder=/usr/local/atnd/
configFile=atnd.conf
configFullPath=$runFolder$configFile
serviceFullName=atnd.service
serviceName=${serviceFullName:0:-8}

##############
# Some Check #
##############
if [ ! -e $runFile ];then
  echo The $atnd.sh is not exist in the same folder. Exit without any change.
  exit 1
fi

set -x
cat /etc/redhat-release | grep 7\..*
set +x
if [ $? -ne 0 ];then
  echo Please make sure your system is CentOS 7 or RedHat 7.
  exit 1
fi

if [ -e $configFullPath ];then
  echo The $configFullPath is existed. Exit without any change.
  exit 1
fi

chmod 755 $runFile
mkdir -p $runFolder $runFolder/log
\cp $runFile $runFolder

##################
# CONSTANT INPUT #
##################
Create_Config
Confirm_Config
confirmResult=$?

# function Confirm_Config Return code
# 0 Confirm OK
# 1 Need re-confirm
# 2 Need re-create config
while [[ $confirmResult -eq 1 || $confirmResult -eq 2 ]];
do
  if [ $confirmResult -eq 2 ];then
    Create_Config
    Confirm_Config
    confirmResult=$?
  elif [ $confirmResult -eq 1 ];then
    Confirm_Config
    confirmResult=$?
  fi
done

cat > /usr/lib/systemd/system/$serviceFullName <<EOF
[Unit]
Description=Auto Tomcat Nginx Docker deploy service
After=syslog.target network.target

[Service]
ExecStart=/usr/local/atnd/atnd.sh
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /usr/lib/systemd/system/$serviceFullName
systemctl daemon-reload
systemctl start $serviceName
systemctl enable $serviceName

sleep 2
set -x
systemctl status $serviceName -l
if [ $? -ne 0 ];then
  echo $serviceName is not active correctly. Please manual check.
  exit 2
  else
    echo $serviceName is running now.
    exit 0
fi
