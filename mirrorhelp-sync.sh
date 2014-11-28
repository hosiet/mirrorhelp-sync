#!/bin/sh

# 自动同步 data/pages/mirrors/ 目录下的文件更改，并合并历史记录
#
## @todo POSIX shell script compatible
# 
# 需求：
# ==============
# 
# 1. 监控目录下的文件更改（包括 /mirrors/ 目录下除了 .git/ 目录
# 以外的所有文件。如有更改，则：
# 
# 1.1 立即 git 添加文件；
# 1.2 通过 data/meta 目录下的记录提取更改信息；
# 1.3 以 www-data 用户身份 git commit, 提交说明添加提取出的信息；
# 1.4 git push.
#
# 2. 定时（或经过触发）在远程 stable 分支被更新时进行更改：
#
# 2.1 git pull 发现内容更新；
# 2.2 提取出更新内容；
# 2.3 进行内容更新；
# 2.4 按照当前时间将更新内容打包留在 data/attic 目录下，同时按照
# 提取出的 Git 更新信息更新 data/meta 目录下对应的 .changes 文件；
#
# -------------------------
#
# 这个脚本先写第一部分

# 备份一遍 changes 文件，这部分以后要放到里面


# 变量声明

DIR_META="/srv/www/wiki/data/meta/mirrors";
DIR_PAGE="/srv/www/wiki/data/pages/mirrors";
DIR_TEMPFILE="/tmp";
DIR_CURRENT=`pwd`;
GIT_COMMIT_MSG="";

# 第一部分, 未测试

refresh_changes()
{
    DIR_CURRENT=`pwd`;
    cd $DIR_META/
    for NAME in `ls | grep \.changes$`; do
        cp $DIR_META/$NAME $DIR_META/$NAME.backup;
    done
    cd $DIR_META/help/
    for NAME in `ls | grep \.changes$`; do
        cp $DIR_META/help/$NAME $DIR_META/help/$NAME.backup;
    done
    cd $DIR_CURRENT;
}

add_user_msg()
{
    cd $1/
    echo " Now in $1"
    for NAME in `ls | grep \.changes$`; do
	NUMBER1=`wc -l $NAME | grep -o [0-9]*`;
	NUMBER2=`wc -l $NAME.backup | grep -o [0-9]*`;
        if [ ! "$NUMBER1" = "$NUMBER2" ]; then
            # 需要获取 EDITOR 信息
            # shell 中判断两个字符串相等使用 "=", 也可以"==" （非POSIX标准）
	    NAME_REAL=`echo $NAME | grep -o "^[a-zA-Z0-9_-]*"`;
            EDITOR_RAW=$(tail -n 1 ./$NAME | grep -E -o "$NAME_REAL.*$");
            #EDITOR_MSG=$(echo $EDITOR_RAW | grep -o "	".*);
	    EDITOR_MSG=$EDITOR_RAW;
            GIT_COMMIT_MSG=" Editor info of "$NAME_REAL".txt: "$EDITOR_MSG;

	    # DEBUG
	    # echo "\$NAME is $NAME"
            # echo "\$NAME_REAL is $NAME_REAL"
	    # echo "\$EDITOR_RAW is $EDITOR_RAW"
	    # echo "\$EDITOR_MSG is $EDITOR_MSG"
	    # echo "\$GIT_COMMIT_MSG is $GIT_COMMIT_MSG"
	    # echo " "
	    # ENDOF DEBUG

            echo $GIT_COMMIT_MSG >> $DIR_TEMPFILE/mirrorhelp-sync.txt;
        fi
    done
}

# 注：利用 $? 判断上一条命令的返回值

# declare -i CHANGE_NUMBER=0;
refresh_changes;
cd $DIR_PAGE/
while true; do
    cd $DIR_PAGE/
    CHANGE_NUMBER=0;
    RAW_STRING=`inotifywait --event modify --event delete --event move $DIR_PAGE/help/ $DIR_PAGE/help.txt \
   $DIR_PAGE/README.md $DIR_PAGE/LICENSE`;

    # 进行锁的判断与实验

    if [ -f $DIR_PAGE/.lock_git2doku ]; then
        sleep 25;
        refresh_changes;
        continue;
    fi
    touch $DIR_PAGE/.lock_doku2git

    # 锁处理结束

    TRIGGER_UNIX_TIME=$(date +%s);
    GIT_COMMIT_MSG="Edit from DokuWiki on "`date +'%Y-%m-%d %H:%S'`;
    echo $GIT_COMMIT_MSG > $DIR_TEMPFILE/mirrorhelp-sync.txt;
    echo " " >> $DIR_TEMPFILE/mirrorhelp-sync.txt;
    FILE_STRING_1=$(echo -n $RAW_STRING | grep -o -E "[A-Za-z-]+\.txt$" --null-data);
    FILE_STRING=$(echo -n $FILE_STRING_1);
    git add $DIR_PAGE/.
    add_user_msg $DIR_META;
    add_user_msg $DIR_META/help;
    cd $DIR_PAGE/
    git commit --file=$DIR_TEMPFILE/mirrorhelp-sync.txt --signoff
    echo "After commit.";
    git fetch;
    git merge origin/master --quiet -m " www-data automatic merge. ";
    git push;
    refresh_changes;
    rm ./.lock_doku2git -f
    sleep 5;
done

