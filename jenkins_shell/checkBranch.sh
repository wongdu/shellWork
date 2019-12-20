#!/bin/bash

#cd yx-tracking-service
# "$BUILD_VERSION_NUM" "$BUILD_PROD" "$APP_VERSION" "$APP_VERSION_CODE"
if [ $# -ne 5 ];then
	echo "parameter number should be equal 4"
	exit 1 
fi

BUILD_VERSION_NUM="$1"
echo "指定构建的版本号BUILD_VERSION_NUM:" $BUILD_VERSION_NUM
BUILD_PROD="$2"
echo "构建生产环境发布版本BUILD_PROD:" $BUILD_PROD
APP_VERSION="$3"
APP_VERSION_CODE="$4"
echo "自定义版本名称APP_VERSION:" $APP_VERSION
echo "自定义版本号APP_VERSION_CODE:" $APP_VERSION_CODE
BUILD_URL="$5"
echo "BUILD_URL is:" $BUILD_URL

function modVersionName(){	
	modifyVersionName=""
	if [ ""x == "$APP_VERSION"x ];then
		modifyVersionName=$BUILD_VERSION_NUM
	else
		modifyVersionName=$APP_VERSION
	fi
	regexValue="^([0-9]+)(\.[0-9]+)*$"
	versionValue=`echo ${modifyVersionName} | grep -E $regexValue`
	if [ ""x == "$versionValue"x ];then
		echo "not valid version name"
		exit 2
	fi
	
        sed -i "s/versionName \(.*\)/versionName \"$modifyVersionName\"/" app/build.gradle
	echo "modify versionName successfully"
    
	return 0
}

function modVersionCode(){
	if [ ""x == "$APP_VERSION_CODE"x ];then
		return 0
	fi
	
	regexValue="^[1-9]*[1-9][0-9]*$"
	APP_VERSION_CODE=`echo ${APP_VERSION_CODE} | grep -E $regexValue`
	if [ "$APP_VERSION_CODE"x == ""x ];then
		echo "not valid version code"
		exit 2
	fi
	
	sed -i "s/versionCode \(.*\)/versionCode $APP_VERSION_CODE/" app/build.gradle
	echo "modify versionCode successfully"

	return 0
}

if [ ""x == "$BUILD_VERSION_NUM"x ];
then
	# 默认是需要构建工程,创建commitLog.txt通知jenkins当前构建流程正常执行
	#touch rebuildFlag.txt
	touch commitLog.txt
	echo "Null of app version, rebuild by default"
    if [ -f "stopNoMatch.txt" ];then
		rm -rf stopNoMatch.txt 
	fi
    if [ -f "stopNoNeed.txt" ];then
		rm -rf stopNoNeed.txt 
	fi
    if [ -f "stopBuildProd.txt" ];then
		rm -rf stopBuildProd.txt 
	fi
    if [ -f "stopBuildAlpha.txt" ];then
		rm -rf stopBuildAlpha.txt 
	fi

	exit 0
else
	echo "BUILD_VERSION_NUM $BUILD_VERSION_NUM"
fi

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
	# 在checkBranch过程中发送消息到群组后退出脚本，所以在函数最后将.git强制修改成jenkins用户拥有
	chown -Rf jenkins:jenkins .git .gradle
}

#echo ${BUILD_VERSION_NUM} | grep '^[[:digit:]][0-9\.]*[[:digit:]]$' |grep -v '\.\.\.*'
#versionValue=`echo ${BUILD_VERSION_NUM} | grep '^[[:digit:]][0-9\.]*[[:digit:]]$'`
regexValue="^([0-9]+)(\.[0-9]+)*$"
versionValue=`echo ${BUILD_VERSION_NUM} | grep -E $regexValue`
if [ ""x == "$versionValue"x ];then
	echo "not valid specification"
	exit 2
fi

# 1.23.1--->1.23
# 1.23--->1.23
BUILD_SUFFIX_PROD_VERSION_NUM=$(echo ${BUILD_VERSION_NUM%%.*})
tempRight=$(echo ${BUILD_VERSION_NUM#*.})
tempLeft=$(echo ${tempRight%%.*})
BUILD_SUFFIX_PROD_VERSION_NUM=$BUILD_SUFFIX_PROD_VERSION_NUM.$tempLeft
echo "build_suffix_prod_version_num: " $BUILD_SUFFIX_PROD_VERSION_NUM

git remote prune origin
remote_name=`git remote -v | grep xxxData | grep fetch | awk '{print $1}'`
regName=$(echo "$remote_name"/alpha_)
echo "regular name:" $regName

git log --graph --all --decorate > gitLog.txt
cat gitLog.txt|grep commit > commitLog.txt
if [ -f "commitLog.txt" ];then
        echo "获取的commit日志文件成功"
else
        echo "获取的commit日志文件失败"
        exit 3
fi

cat commitLog.txt  |grep "$remote_name" > remoteBranch.txt
if [ -f "remoteBranch.txt" ];then
        echo "获取远程仓库分支成功"
else
        echo "获取远程仓库分支名失败"
        exit 4
fi

cat /dev/null > remoteBranchName.txt
while read line; do
	# get conten in the last parentthese
	echo `echo $line  |sed 's/\(^\|)\)[^(]*\((\|$\)/ /g'` >> remoteBranchName.txt
done < remoteBranch.txt
if [ -f "remoteBranchName.txt" ];then
        echo "获取远程仓库分支名成功"
else
        echo "获取远程仓库分支名失败"
        exit 5
fi

remoteBranchNum=()
while read line; do
	array=(${line//,/ })
	for var in ${array[@]}
	do
		var=$(echo $var |grep "$remote_name/alpha_")
		if [ "$var"x == ""x ];then
			continue
		fi
		branchNum=$(echo ${var##"$remote_name/alpha_"})
		if [ "$branchNum"x == ""x ];then
			continue
		fi
		echo $branchNum
        remoteBranchNum[${#remoteBranchNum[@]}]=$branchNum
	done 
done < remoteBranchName.txt	
echo "测试版本集合：" ${remoteBranchNum[@]}

#sort the alpha branch array
len=${#remoteBranchNum[@]}
echo $len
for((i=0; i<$len; i++)){
  for((j=i+1; j<$len; j++)){ 
    if [[ `expr ${remoteBranchNum[i]} \> ${remoteBranchNum[j]}` -eq 0  ]]
    then
      temp=${remoteBranchNum[i]}
      remoteBranchNum[i]=${remoteBranchNum[j]}
      remoteBranchNum[j]=$temp
    fi 
  }
}
echo "排序后的测试版本集合：" ${remoteBranchNum[@]}

if [ "true"x == "$BUILD_PROD"x ];then
	#构建生产环境发布版本
    if [ -f "stopNoMatch.txt" ];then
        echo "remove the old stop flag file,no need do this in gerenal"
		rm -rf stopNoMatch.txt 
	fi
	remoteProdBranchNum=()
	while read line; do
		array=(${line//,/ })
		for var in ${array[@]}
		do
			var=$(echo $var |grep "$remote_name/prod_")
			if [ "$var"x == ""x ];then
				continue
			fi
			branchNum=$(echo ${var##"$remote_name/prod_"})
			if [ "$branchNum"x == ""x ];then
				continue
			fi
			echo $branchNum
			remoteProdBranchNum[${#remoteProdBranchNum[@]}]=$branchNum
		done 
	done < remoteBranchName.txt	
	echo "生产环境发布版本集合：" ${remoteProdBranchNum[@]}
	
	#sort the production branch array
	len=${#remoteProdBranchNum[@]}
	echo $len
	for((i=0; i<$len; i++)){
	  for((j=i+1; j<$len; j++)){ 
		if [[ `expr ${remoteProdBranchNum[i]} \> ${remoteProdBranchNum[j]}` -eq 0  ]]
		then
		  temp=${remoteProdBranchNum[i]}
		  remoteProdBranchNum[i]=${remoteProdBranchNum[j]}
		  remoteProdBranchNum[j]=$temp
		fi 
	  }
	}
	echo "排序后的生产环境发布版本集合：" ${remoteProdBranchNum[@]}
	
	rebuild=false
	for((i=0;i<${#remoteProdBranchNum[@]};i++))
	do
	 #echo "num is: ${remoteProdBranchNum[i]}"
	 if [ "${remoteProdBranchNum[i]}"x == "$BUILD_VERSION_NUM"x ];then
		echo "need build existed version"
		rebuild=true
		break
	 fi
	done
	if [ "true"x == "${rebuild}"x ];then
			echo "rebuild current existed version"
			touch rebuildFlag.txt
	else
			echo "not rebuild current existed version"
			if [ -f "rebuildFlag.txt" ];then
					echo "remove the rebuild flag txt if exits"
					rm -rf rebuildFlag.txt
			fi
			matchAlpha=false
			for((i=0;i<${#remoteBranchNum[@]};i++))			
			do
				#if [ "${remoteBranchNum[i]}"x == "$BUILD_VERSION_NUM"x ];then
                if [ "${remoteBranchNum[i]}"x == "$BUILD_SUFFIX_PROD_VERSION_NUM"x ];then
					echo "need build existed alpha version"
					matchAlpha=true
					break
				fi			
			done
            matchProdWhileNoMatchAlpha=false
            if [ "false"x == "$matchAlpha"x ];then
                for((i=0;i<${#remoteProdBranchNum[@]};i++))			
			    do
				    #if [ "${remoteBranchNum[i]}"x == "$BUILD_VERSION_NUM"x ];then
                    if [ "${remoteProdBranchNum[i]}"x == "$BUILD_SUFFIX_PROD_VERSION_NUM"x ];then
					    echo "need build existed pord version"
					    matchProdWhileNoMatchAlpha=true
					    break
				    fi			
			    done
            fi
			if [ "false"x == "$matchAlpha"x -a "false"x == "$matchProdWhileNoMatchAlpha"x ];then
                touch stopNoMatch.txt #just tell modVersion script to stop build prod branch
				#echo "there is no match alpha version ,so just stop current build process"
				if [ ! ""x == "$BUILD_URL"x ];then
					# abort current build process,cause there is no match alpha version
					echo "cause there is no match alpha version, abort the build pro: ${BUILD_URL}stop"
					curl --user jenkinsUser:jenkinsPassword -d "" "${BUILD_URL}stop"
               			fi 
				curr_path=`pwd`
				proName=`echo ${curr_path##*/}`
				text=$(echo "${proName} doesnt have alpha$BUILD_VERSION_NUM branch,so cannot build prod$BUILD_VERSION_NUM branch ")                
				title=$(echo "待构建生产分支未能成功匹配到alpha分支，也未能成功匹配到prod分支")
				SendToDingding "${title}" "${text}" 
				exit 0
			fi
	fi
	
else
	#默认为构建测试版本
	if [ -f "stopNoNeed.txt" ];then
        echo "remove the old stop flag file,no need do this in gerenal"
		rm -rf stopNoNeed.txt 
	fi

	rebuild=false
	for((i=0;i<${#remoteBranchNum[@]};i++))
	do
	 #echo "num is: ${remoteBranchNum[i]}"
	 if [ "${remoteBranchNum[i]}"x == "$BUILD_VERSION_NUM"x ];then
		echo "need build existed version"
		rebuild=true
		break
	 fi
	done
	#touch rebuildFlag.txt if current build is rebuild, cause modVersion.sh will check it 
	#if [ ${rebuild} ];then
	if [ "true"x == "${rebuild}"x ];then
			echo "rebuild current existed version"
			touch rebuildFlag.txt
	else
			echo "not rebuild current existed version"
			if [ -f "rebuildFlag.txt" ];then
					echo "remove the rebuild flag txt if exits"
					rm -rf rebuildFlag.txt
			fi
	fi

	newVersion=false
	existNumVersion=false
	biggsetVersion=""
	#if remote branch num exits,and new version is bigger than the biggest
	if [ $len -gt 0 ];then
		for((i=0;i<${#remoteBranchNum[@]};i++))
        	do
            		regCheckAlpha="^([0-9]+)(\.[0-9]+)*$"
            		checkAlphaValue=`echo ${remoteBranchNum[i]} | grep -E $regCheckAlpha`
            		if [ ""x == "$checkAlphaValue"x ];then
	            		echo "alpah branch num " ${remoteBranchNum[i]} "is not regular"
			        continue            
            		else
                		existNumVersion=true
                		biggsetVersion=${remoteBranchNum[i]}
               			if [[ `expr ${BUILD_VERSION_NUM} \> ${remoteBranchNum[i]}` -eq 1 ]];then
			        	echo "need build new version"
			        	newVersion=true                    
		        	fi
                		#从大到小找到第一个合法的最大的远程alpha分支名称
                		break
            		fi
        	done
	else
		#there is no other remote branch except master branch
		newVersion=true
	fi

	#并没有发过版本，即不存在remotes/origin/alpha_1.21，
    	#就算存在alpha分支，也是remotes/origin/alpha_activity_1103这样的分支
    	#if[ "false"x == "${existNumVersion}"x ];then
    	if [ "false"x == "${existNumVersion}"x ];then
        	#如果不存在alpha分支，前面的else分支已经设置了new version variable，但是此处重复不会有影响
        	newVersion=true
    	fi

	#if [ ! ${rebuild} -a ! ${newVersion} ];then
	if [ "false"x == "${rebuild}"x -a "false"x == "${newVersion}"x ];then
		echo "new version num is muster be the biggest"
		curr_path=`pwd`
		proName=`echo ${curr_path##*/}`
		text=$(echo "${proName}'s last builded version is $biggsetVersion, ${BUILD_VERSION_NUM} should bigger than it")                
		title=$(echo "传入的版本号要大于当前最大版本号: $biggsetVersion")
		SendToDingding "${title}" "${text}" 
		exit 7
	fi

	#需要从master拉新的分支并推送到远程仓库，但是如果master并没有更新则直接退出不报错
	#if [ `${newVersion}` ];then
	if [ "true"x == "${newVersion}"x ];then
		headCommit=`head -n +1 commitLog.txt`
		echo $headCommit
		# get conten in the last parentthese
		branchLog=$(echo $headCommit |sed 's/\(^\|)\)[^(]*\((\|$\)/ /g')
		#noNeedBuild=$(echo $branchLog |grep "origin/alpha_")
		#noNeedBuild=$(echo $branchLog |grep "[origin/alpha_|origin/prod_]")
		noNeedBuild=$(echo $branchLog |grep -E "origin/(alpha_|prod_)")
		if [ ""x == "$noNeedBuild"x ];then
			echo "has not been builded after new change on master,so build it"
		else
            touch stopNoNeed.txt #just tell modVersion script to stop build prod branch
			#$noNeedBuild is not null means there is no new change on master ,so no need build
			echo "no need build"
			rm -rf gitLog.txt commitLog.txt
			curr_path=`pwd`
                        proName=`echo ${curr_path##*/}`
			if [ ! ""x == "$BUILD_URL"x ];then
				# abort current build process,cause has been builded, no need to build new version
				echo "cause $proName has been builded, no need to build new version $BUILD_VERSION_NUM, abort the build pro: ${BUILD_URL}stop"
				curl --user jenkinsUser:jenkinsPassword -d "" "${BUILD_URL}stop"
			fi 
			text=$(echo "$proName has been builded, no need to build new version $BUILD_VERSION_NUM")
			title="当前版本不需要打包， 请喝杯咖啡，休息一会吧"
			echo $title
			SendToDingding "${title}" "${text}"
			exit 0
		fi
	fi
fi


# check remote name
remote_name=`git remote -v | grep xxxData | grep fetch | awk '{print $1}'`
echo "get remote_name is $remote_name"


if [ "true"x == "$BUILD_PROD"x ];then
	#构建生产环境发布版本
        if [ -f "stopBuildProd.txt" ];then
        	echo "remove the old stop flag file,no need do this in gerenal"
		rm -rf stopBuildProd.txt 
	fi

	# clean env
        #git checkout . && git checkout "alpha_$BUILD_VERSION_NUM" && git pull $remote_name "alpha_$BUILD_VERSION_NUM"
        #git checkout . && git checkout "alpha_$BUILD_SUFFIX_PROD_VERSION_NUM" && git pull $remote_name "alpha_$BUILD_SUFFIX_PROD_VERSION_NUM"
        if [ "true"x == "$matchAlpha"x ];then
		checkAlphaBranch=`git branch -a | grep -v remotes | grep "alpha_$BUILD_SUFFIX_PROD_VERSION_NUM"`
		if [ ""x == "$checkAlphaBranch"x ];then
                	# 如果不存在本地的目标分支就创建一个该分支
                	git checkout -b "alpha_$BUILD_SUFFIX_PROD_VERSION_NUM"
            	fi
            	git checkout . && git checkout "alpha_$BUILD_SUFFIX_PROD_VERSION_NUM" && git pull $remote_name "alpha_$BUILD_SUFFIX_PROD_VERSION_NUM"
        elif [ "true"x == "$matchProdWhileNoMatchAlpha"x ];then
		checkProdBranch=`git branch -a | grep -v remotes | grep "prod_$BUILD_SUFFIX_PROD_VERSION_NUM"`
		if [ ""x == "$checkProdBranch"x ];then
                	# 如果不存在本地的目标分支就创建一个该分支
                	git checkout -b "prod_$BUILD_SUFFIX_PROD_VERSION_NUM"
            	fi
            	git checkout . && git checkout "prod_$BUILD_SUFFIX_PROD_VERSION_NUM" && git pull $remote_name "prod_$BUILD_SUFFIX_PROD_VERSION_NUM"
        fi
        echo "clean production env"

	local_target_branch=`git branch -a | grep -v remotes | grep "prod_$BUILD_VERSION_NUM"`
	remote_target_branch=`git branch -a | grep "remotes/$remote_name" | grep "prod_$BUILD_VERSION_NUM"`
	echo "local_target_branch:"  $local_target_branch 
	echo "remote_target_branch:" $remote_target_branch
	if [ ""x != "$local_target_branch"x ];
	then
		echo "exists local branch, checkout it and pull new code"
		git checkout $local_target_branch && git pull $remote_name $local_target_branch
	else
		echo "not exists local branch"
		if [ ""x != "$remote_target_branch"x ];
		then
			echo "but exists remote branch, pull it"
			git checkout -b "prod_$BUILD_VERSION_NUM" "$remote_name/prod_$BUILD_VERSION_NUM"
		else
			echo "and not exists remote branch, create new branch by local/remote master"
			git checkout -b "prod_$BUILD_VERSION_NUM"
            echo "修改prod_XXX分支的versionname ,然后push到git仓库"
			if [ ! -f "app/build.gradle" ];then
				echo "app/build.gradle dosent exist"
				exit 4
			fi
            dos2unix app/build.gradle
			modVersionName
			modVersionCode
            commitMsg="new versionName:$BUILD_VERSION_NUM"
            		if [ ! ""x == "$APP_VERSION_CODE"x ];then
		        	commitMsg=$commitMsg",new versionCode:$APP_VERSION_CODE"
	        	fi 

			echo "here is comment out the push command"
            git add app/build.gradle
			git commit -m "chore: jenkins checkout production branch: $commitMsg"
			git push $remote_name "prod_$BUILD_VERSION_NUM"
			
			echo "create tag and delete old prod branch when push new branch "
			for((i=0;i<${#remoteProdBranchNum[@]};i++))
			do
		                git checkout . && git checkout "${remote_name}/prod_${remoteProdBranchNum[i]}"
				commidId=$(git log --pretty=oneline --abbrev-commit | head -n 1 |awk '{print $1}')
               			git tag -a "tagP_${remoteProdBranchNum[i]}" -m "prod ${remoteProdBranchNum[i]} branch deleted" "$commidId"
                		git push origin "tagP_${remoteProdBranchNum[i]}" #push local tag to remote

		                echo "delete the old local and remote prod branch"
              			git branch -D "prod_${remoteProdBranchNum[i]}" > /dev/null 2>&1
               			git push origin --delete "prod_${remoteProdBranchNum[i]}" > /dev/null 2>&1
			done
			
			commitMsg="new versionName:$BUILD_VERSION_NUM"
			curr_path=`pwd`
			proName=`echo ${curr_path##*/}`
			text=$(echo "${proName} checkout production branch: $commitMsg")                
			title=$(echo "往git仓库推送新的production分支")
			echo "${title}" "${text}"
			#SendToDingding "${title}" "${text}" 
			
			#如果是从prod分支切出prod小版本分支不进行合并
			#if [ "true"x == "$matchAlpha"x ];then
			#merge prod branch to master
			echo "merge prod branch to master"
			#git config --list
			checkMasterBranch=`git branch -a | grep -v remotes | grep master`
            		if [ ""x == "$checkMasterBranch"x ];then
                		# 如果不存在本地的master分支就创建一个该分支
                		git checkout -b master
            		fi
		        git checkout . && git checkout master
			git pull origin master
			# git branch --set-upstream-to=origin/master master
			# git pull
			
			echo "prod branch prod_${BUILD_VERSION_NUM}" 
			#git config --global push.default simple
		        mergeLog=$(git merge "prod_${BUILD_VERSION_NUM}")
        	    	unset mergeConflict
	        	if [ ! "$mergeLog"x == ""x ];then
            			mergeConflict=$(echo $mergeLog | grep CONFLICT)
                		if [ ! "$mergeConflict"x == ""x ];then
                    			#merge confict
					echo "merge from prod branch to master conflict: " "$mergeLog"
				        git merge --abort
                	    		text=$(echo "${proName} prod_${BUILD_VERSION_NUM}分支合并出现冲突，请手动merge")                
				        title=$(echo "production分支合并到master分支")
                    			SendToDingding "${title}" "${text}" 
	                	else
					echo "push merge from prod branch to master"
                	    		git push 
                		fi
            		fi
			#fi
       			touch stopBuildProd.txt #just tell modVersion script to stop build production
			if [ ! ""x == "$BUILD_URL"x ];then
				# abort current build process,cause it just push production branch to git repository
				echo "abort the build pro: ${BUILD_URL}stop"
				curl --user jenkinsUser:jenkinsPassword -d "" "${BUILD_URL}stop"
                        fi 
			
			exit 0
		fi
	fi
else
	# 默认为构建测试版本
	if [ -f "stopBuildAlpha.txt" ];then
        	echo "remove the old stop flag file,no need do this in gerenal"
		rm -rf stopBuildAlpha.txt 
	fi

	# clean env
	checkMasterBranch=`git branch -a | grep -v remotes | grep master`
    	if [ ""x == "$checkMasterBranch"x ];then
        	# 如果不存在本地的master分支就创建一个该分支
        	git checkout -b master
    	fi
        git checkout . && git checkout master && git pull $remote_name master
        echo "clean test env"

	# checkout version branch, pull code or create it 
	local_target_branch=`git branch -a | grep -v remotes | grep "alpha_$BUILD_VERSION_NUM"`
	remote_target_branch=`git branch -a | grep "remotes/$remote_name" | grep "alpha_$BUILD_VERSION_NUM"`
	echo "local_target_branch:"  $local_target_branch 
	echo "remote_target_branch:" $remote_target_branch
	if [ ""x != "$local_target_branch"x ];
	then
		echo "exists local branch, checkout it and pull new code"
		git checkout $local_target_branch && git pull $remote_name $local_target_branch
	else
		echo "not exists local branch"
		if [ ""x != "$remote_target_branch"x ];
		then
			echo "but exists remote branch, pull it"
			git checkout -b "alpha_$BUILD_VERSION_NUM" "$remote_name/alpha_$BUILD_VERSION_NUM"
		else			
			echo "and not exists remote branch, create new branch by local/remote master"
			git checkout -b "alpha_$BUILD_VERSION_NUM"
			echo "修改alpha_XXX分支的versionname ,然后push到git仓库"
			if [ ! -f "app/build.gradle" ];then
				echo "app/build.gradle dosent exist"
				exit 4
			fi
			dos2unix app/build.gradle
			modVersionName
			modVersionCode

			commitMsg="new versionName:$BUILD_VERSION_NUM"
            		if [ ! ""x == "$APP_VERSION_CODE"x ];then
		        	commitMsg=$commitMsg",new versionCode:$APP_VERSION_CODE"
	        	fi 

			echo "here is comment out the push command"
			git push $remote_name "alpha_$BUILD_VERSION_NUM"
			# 提交versionName、versionCode的修改到新建的alpha远程分支上
			git config user.name "jenkins_android"
			git config user.email "xxx@xxx.com.cn"
			branch_name=$(git symbolic-ref --short -q HEAD)
			git add app/build.gradle
			#git commit -m "just push modified app/build.gradle to new alpha branch"
			git commit -m "chore: jenkins checkout alpha branch: $commitMsg"
			git push $remote_name "$branch_name"
			
			echo "create tag and delete old alpha branch when push new branch "
			for((i=0;i<${#remoteBranchNum[@]};i++))
			do
                		git checkout . && git checkout "${remote_name}/alpha_${remoteBranchNum[i]}"
				commidId=$(git log --pretty=oneline --abbrev-commit | head -n 1 |awk '{print $1}')
                		git tag -a "tagA_${remoteBranchNum[i]}" -m "alpha ${remoteBranchNum[i]} branch deleted" "$commidId"
                		git push origin "tagA_${remoteBranchNum[i]}" #push local tag to remote

                		echo "delete the old local and remote alpha branch"
                		git branch -D "alpha_${remoteBranchNum[i]}" > /dev/null 2>&1
                		git push origin --delete "alpha_${remoteBranchNum[i]}" > /dev/null 2>&1
			done
			
			curr_path=`pwd`
			proName=`echo ${curr_path##*/}`
			text=$(echo "${proName} checkout alpha branch: $commitMsg")                
			title=$(echo "往git仓库推送新的alpha分支")
			#SendToDingding "${title}" "${text}" 	
			echo "${title}" "${text}"
			
			touch stopBuildAlpha.txt #just tell modVersion script to stop build alpha branch
			if [ ! ""x == "$BUILD_URL"x ];then
				# abort current build process,cause it just push alpha branch to git repository
				echo "abort the build pro: ${BUILD_URL}stop"
				curl --user jenkinsUser:jenkinsPassword -d "" "${BUILD_URL}stop"
                        fi 
			
			exit 0
		fi
	fi
fi


# 添加分支后.git/logs/refs/remotes/origin/alpha\/prod*为root所拥有，强制修改成jenkins用户拥有
chown -Rf jenkins:jenkins .git .gradle

# build it
echo "======================="
echo "edit your build command"
echo "======================="


