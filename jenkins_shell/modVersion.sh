#!/bin/bash


if [ -f "stopNoMatch.txt" ];then
        echo "there is no match alpha branch ,so just stop current build process"
        rm -rf stopNoMatch.txt commitLog.txt
        exit 0
fi

if [ -f "stopNoNeed.txt" ];then
        echo "there is no new update,no need build ,so just stop current build process"
        rm -rf stopNoNeed.txt commitLog.txt
        exit 0
fi

if [ -f "stopBuildAlpha.txt" ];then
        echo "push alpha branch ,so just stop current build process"
        rm -rf stopBuildAlpha.txt commitLog.txt
        exit 0
fi

if [ -f "stopBuildProd.txt" ];then
        echo "push prod branch ,so just stop current build process"
        rm -rf stopBuildProd.txt commitLog.txt
        exit 0
fi

if [ $# -ne 5 ];then
        echo "parameter num is not valid"
        exit 1
fi

BUILD_VERSION_NUM=$1
echo "指定构建的版本号BUILD_VERSION_NUM:" $BUILD_VERSION_NUM
BUILD_PROD=$2
echo "构建生产环境发布版本BUILD_PROD:" $BUILD_PROD
APP_VERSION=$3
APP_VERSION_CODE=$4
echo "自定义版本名称APP_VERSION:" $APP_VERSION
echo "自定义版本号APP_VERSION_CODE:" $APP_VERSION_CODE

BRANCH=$5
echo "构建远程分支名称BRANCH:" $BRANCH ",默认值为origin/master"

curr_time=""
str=""
pwd

function SendToDingding(){ 
    #dingding="https://oapi.dingtalk.com/robot/send?access_token=ac1947e68dc2c4d9f290e4751824ba53e52a680d9aebd6ca2a5e07f16d2a2dea"
    dingding="https://oapi.dingtalk.com/robot/send?access_token=5b51ab82d7faebb091cba04d434613db059e279400fd81f75ddfc4f15dd7b0cf"
    curl "${dingding}" -H 'Content-Type: application/json' -d "
    {
        \"actionCard\": {
            \"title\": \"$1\", 
            \"text\": \"$2\", 
            \"hideAvatar\": \"0\", 
            \"btnOrientation\": \"0\", 
            \"btns\": [
                {
                    \"title\": \"$1\", 
                    \"actionURL\": \"\"
                }
            ]
        }, 
        \"msgtype\": \"actionCard\"
    }"
} 

#$BUILD_VERSION_NUM is null or a valid parameter,cause regular expression has been checked in build.sh
if [ ""x != "$BUILD_VERSION_NUM"x ];then
	if [ "$BRANCH"x == "origin/master"x ];then
		echo "modify the default BRANCH value when BUILD_VERSION_NUM is not null"
		if [ "true"x == "$BUILD_PROD"x ];then
			BRANCH="origin/prod_"$BUILD_VERSION_NUM
		else
			BRANCH="origin/alpha_"$BUILD_VERSION_NUM
		fi		
		echo "after modified,branch name is :" $BRANCH
	fi
	if [ -f "rebuildFlag.txt" ];then
		echo "current build is rebuild old version"
	elif  [ ! -f "commitLog.txt" ];then
		echo "current build is a new build version,but no need build ,so just exit"
                curr_path=`pwd`
		proName=`echo ${curr_path##*/}`
		text=$(echo "$proName has been builded, no need to build new version $BUILD_VERSION_NUM")
		title="当前版本不需要打包， 请喝杯咖啡，休息一会吧"
		#SendToDingding "${title}" "${text}"
		exit 0
	fi
fi

if [ -f "app/build.gradle" ];then
        echo "文件存在"
else
        echo "app/build.gradle 文件不存在"
        exit 1
fi

#判断是否需要修改versionName并执行相应操作
branchName=$(echo ${BRANCH##*/})
branchName=$(echo ${branchName%_*})
curr_time=`date +"%m%d%H%M"` #自定义版本号
str=""
if [ "$APP_VERSION"x == ""x ];then
	#echo "自定义版本号为空，不需要修改生成包的versionName"
	echo "自定义版本号为空，修改master的versionName为m<MMddHHmm>,测试分支的versionName为<version_name>.<MMddHHmm>"
	if [ "$BUILD_VERSION_NUM"x == ""x ];then
		echo "versionName is null and BUILD_VERSION_NUM also is null,maybe build the master branch or sub branch"
		dos2unix app/build.gradle
		verName=`cat app/build.gradle |grep versionName | head -n 1`
		verName=`echo ${verName##* }`
		verName=`echo $verName | sed 's/\"//g'`
		echo "old versionName is " "$verName"
		BUILD_VERSION_NUM="$verName"	
	fi
	if [ "$branchName"x == "master"x ];then
		echo "master version name is m<MMddHHmm> "
		str=\"m${curr_time}\"
	elif [ "$branchName"x == "alpha"x ];then
		echo "alpha branch version name is <version_name>.<MMddHHmm> "
		#for alpha version,there is a alpha_ prefix
		str=\"alpha_$BUILD_VERSION_NUM.${curr_time}\"
	elif [ "$branchName"x == "prod"x ];then
		echo "prod branch version name is <version_name> "
		#for production version,there is no prod_ prefix
		str=\"$BUILD_VERSION_NUM\"
	else
		echo "other branch version name is ${branchName}_<version_name>.<MMddHHmm> "
                str=\"${branchName}_${BUILD_VERSION_NUM}.${curr_time}\"
	fi
        sed -i "s/versionName \(.*\)/versionName $str/" app/build.gradle
        echo "modify versionName successfully"
	echo "after versionName modified, the new value is" $str
	
else
	#自定义版本号必须是数字格式
	regexValue="^([0-9]+)(\.[0-9]+)*$"
	APP_VERSION=`echo ${APP_VERSION} | grep -E $regexValue`
	if [ "$APP_VERSION"x == ""x ];then
		echo "定义版本号必须是数字格式，输入错误"
		exit 2
	else
		if [ "$branchName"x == "master"x ];then
		    	echo "master version name is m_${APP_VERSION}.<MMddHHmm> "
		    	str=\"m_${APP_VERSION}.${curr_time}\"
	    	elif [ "$branchName"x == "alpha"x ];then
		    	echo "alpha branch version name is <version_name>.<MMddHHmm> "
		    	#for alpha version,there is a alpha_ prefix
		    	str=\"alpha_${APP_VERSION}.${curr_time}\"
	    	elif [ "$branchName"x == "prod"x ];then
		    	echo "prod branch version name is <version_name> "
		    	#for production version,there is no prod_ prefix
		    	str=\"${APP_VERSION}\"
	    	else
			echo "other branch version name is ${branchName}_<version_name>.<MMddHHmm> "
                    	str=\"${branchName}_${APP_VERSION}.${curr_time}\"
	    	fi
		#curr_time=`date +"%m%d%H%M"` #自定义版本号
        	#sed -i "s/versionName \(.*\)/versionName \"${APP_VERSION}.${curr_time}\"/" app/build.gradle
		sed -i "s/versionName \(.*\)/versionName $str/" app/build.gradle
        	echo "modify self defined versionName successfully" 
	fi
fi

#判断是否需要修改versionCode并执行相应操作

if [ "$APP_VERSION_CODE"x == ""x ]
then
	echo "自定义Code号为空，不需要修改生成包的versionCode"
else
	#自定义Code号必须是正整数格式
	regexValue="^[1-9]*[1-9][0-9]*$"
	APP_VERSION_CODE=`echo ${APP_VERSION_CODE} | grep -E $regexValue`
	if [ "$APP_VERSION_CODE"x == ""x ];then
		echo "自定义Code号必须是正整数格式，输入错误"
       		exit 3
	else
        sed -i "s/versionCode \(.*\)/versionCode ${APP_VERSION_CODE}/" app/build.gradle
        echo "modify versionCode successfully"
	fi
fi

if [ -d "app/build" ];then
	echo "remove the app/build directory"
	rm -rf app/build
fi
if [ -d "app/.externalNativeBuild" ];then
	echo "remove the app/.externalNativeBuild directory"
	rm -rf app/.externalNativeBuild
fi

chown -Rf jenkins:jenkins gradlew 

exit 0


