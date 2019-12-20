#!/bin/bash


if [ $# -ne 2 -a $# -ne 3 ];then
        echo "parameter num is not 1,error !!!"
        exit 1
fi

BRANCH="$1"
echo "BRANCH is:" $BRANCH
BUILD_PROD="$2"
echo "构建生产环境发布版本BUILD_PROD:" $BUILD_PROD
PRODUCT_FLAVORS="$3"
if [ $# -ne 3 ];then
	echo "选择要构建的商场是:" $PRODUCT_FLAVORS
fi

if [ -f "app/build.gradle" ];then
	echo "文件存在"
else
	echo "app/build.gradle 文件不存在"
	exit 1
fi

#先格式化build.gradle文件，然后获取versionName值，用来给生成包命名
dos2unix app/build.gradle
verName=`cat app/build.gradle |grep versionName | head -n 1`
verName=`echo ${verName##* }`
verName=`echo $verName | sed 's/\"//g'`
echo $verName

verCode=`cat app/build.gradle | grep versionCode | head -n 1`
verCode=`echo ${verCode##* }`
verCode=`echo $verCode | sed 's/\"//g'`
echo $verCode
regexValue="^[1-9]*[1-9][0-9]*$"
verCode=`echo ${verCode} | grep -E $regexValue`
if [ "$verCode"x == ""x ];then
	echo "version code must be positive integer"
	exit 2		
fi

if [ "true"x == "$BUILD_PROD"x ];then
	BRANCH="origin/prod_"$verName
fi

branchName=$(echo ${BRANCH##*/})
realBranchName=$(echo ${branchName%_*})
: << !
if [ "$branchName"x == "master"x ];then
	branchName=$verName
else
	curr_time=`date +"%m%d_%H%M"`
	branchName+="+"
	branchName+=$verCode
	branchName+=$curr_time
fi
!
branchName="$verName"
echo "add version and deploy versionCode:" $branchName

echo "realBranchName is :" $realBranchName
echo "version name is :" $verName
: << !
if [ "$realBranchName"x == "master"x -o "$realBranchName"x == "prod"x ];then
	echo "push production backend"
	tokenValue="HN8uaw2ErRi5gvcC"
	uploadFileUrl="http://pro.xxx.cn/api/deployment/uploadFile"
	addVersionAndDeployUrl="http://pro.xxx.cn/api/deployment/addVersionAndDeploy"
else
	echo "push test backend"
	tokenValue="HN8uaw2ErRi5gvcB"
	uploadFileUrl="http://test.xxx.cn/api/deployment/uploadFile"
	addVersionAndDeployUrl="http://test.xxx.cn/api/deployment/addVersionAndDeploy"
fi
!
	
packageName=`cat app/build.gradle |grep applicationId`
packageName=`echo ${packageName##* }`
packageName=`echo $packageName | sed 's/\"//g'`
echo $packageName
if [ ""x == "$packageName"x ];then
	echo "got null packageName"
	exit 3
fi

CURR_PATH=`pwd`
cd /home/jenkinsAndroid/jenkinsSignature
pwd
OldApkPath=$CURR_PATH/app/build/outputs/apk/release
fileName=`echo ${CURR_PATH##*/}`
#filter the first yx_pro_android_ 
fileName=$(echo ${fileName:15})
#if [ "android_yx-fengmap"x == "$fileName"x ];then
if [ ! ""x == "${PRODUCT_FLAVORS}"x ];then
	OldApkPath=$CURR_PATH/app/build/outputs/apk/${PRODUCT_FLAVORS}/release
	fileName=$(echo ${fileName##*_})
	fileName=${fileName}_${PRODUCT_FLAVORS}
fi
echo -e $fileName
fileName=$fileName\_$verName
echo -e $fileName
fileName=`echo ${fileName} | sed 's/^M//g'`
echo $fileName.apk

: << !
if [ "$SYSTEM_SIGNATURE"x == "true"x ]
then
	echo "给生成的包打上系统签名"
	java -jar signapk.jar platform.x509.pem platform.pk8 $OldApkPath/*.apk $fileName.apk
else
	echo "普通应用程序包，直接拷贝至目标目录/home/jenkinsAndroid/jenkinsSignature，无需打系统签名"
	mv $OldApkPath/*.apk $fileName.apk
fi
!
mv $OldApkPath/*.apk $fileName.apk

#fir login 722e161ad78ba8165cd90106764dfe0c
#fir me
#fir p $fileName.apk -T 722e161ad78ba8165cd90106764dfe0c --dingtalk-access-token=5b51ab82d7faebb091cba04d434613db059e279400fd81f75ddfc4f15dd7b0cf
#fir p $fileName.apk -T 722e161ad78ba8165cd90106764dfe0c --dingtalk-access-token=5c528efc5f3af163d2d737c043a76801cb993d44c9b1bc9ffc20403d36976f1d #xxx Android

curlRetMsg=$(curl $uploadFileUrl  -F "file=@$fileName.apk" -X POST -H "token:$tokenValue")
echo "the return message after upload file to backend:"
echo ${curlRetMsg} | jq
retCode=$(echo ${curlRetMsg} | jq -r '.code')
if [ ! $retCode -eq 0 ];then
	failMsg=$(echo ${curlRetMsg} | jq -r '.msg')
	echo "upload file failed code=$retCode, faileMsg=$failMsg."
	exit 4
else
	echo "upload file succ"
fi

keyUrl=$(echo ${curlRetMsg} | jq -r '.data.url')
echo $keyUrl
if [ ""x == "$keyUrl"x ];then
	echo "got null key url"
	exit 5
fi

#curlRetMsg=$(curl $addVersionAndDeployUrl  -X POST -H "token:$tokenValue" -H 'Content-type':'application/json' -d '{"fileUrl":"'$keyUrl'","typeCode":"'$packageName'","versionCode":"'$branchName'"}')
curlRetMsg=$(curl $addVersionAndDeployUrl  -X POST -H "token:$tokenValue" -H 'Content-type':'application/json' -d '{"fileUrl":"'$keyUrl'","typeCode":"'$packageName'","versionLine":"'$realBranchName'","versionCode":"'$branchName'"}')
retCode=$(echo ${curlRetMsg} | jq -r '.code')
if [ ! $retCode -eq 0 ];then
	failMsg=$(echo ${curlRetMsg} | jq -r '.msg')
    	echo "add version and deploy failed code=$retCode, faileMsg=$failMsg."
	exit 6
else
	echo "add version and deploy succ"
fi

exit 0

