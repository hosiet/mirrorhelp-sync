#!/bin/sh

# 这个脚本负责进行定期检查 git 更新与否，并尝试将更新内容合并。
# 另外，需要进行更新上锁。.lock_git2doku

# 还没有解决方法，先写一个简易的东西。

DIR_META="/srv/www/wiki/data/meta/mirrors";
DIR_PAGE="/srv/www/wiki/data/pages/mirrors";
DIR_TEMPFILE="/tmp";
DIR_CURRENT=`pwd`;
GIT_COMMIT_MSG="";

cd $DIR_PAGE/;
if ! [ -f .lastcommit ]; then
	touch .lastcommit;
	echo $(git show HEAD --pretty=oneline | grep -o "^[0-9a-f][0-9a-f][0-9a-f]* ") > .lastcommit;
fi

while [ -f .lock_doku2git ]; do
	sleep 60;
done
touch .lock_git2doku;
git pull;
rm .lock_git2doku -f;

