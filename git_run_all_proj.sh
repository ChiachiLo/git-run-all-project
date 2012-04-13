#!/bin/bash
# Program:
#       Project tool function.
# Copyright (C) Lo Chia Chi
#
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
# jack989_lo@compalcomm.com
# lo.chiachi@gmail.com
#
# History:
# 2010/12/15 first veriosn.
# 2012/03/20 Add SERVER_MODE 選項
#            加入 Log 系統
#            刪除 JOBS 支援
#            加入 SERVER_ALL_PROJECT 選項
#git_run_all_proj.sh FILE=xxx.xml <USE_SYS_PROXY> <SERVER_MODE> <SERVER_ALL_PROJECT> command_line

#Ex:
# git_run_all_proj.sh FILE=xxx.xml SERVER_MODE git log -1
# git_run_all_proj.sh SERVER_ALL_PROJECT git log -1


MY_PWD=`pwd`

PROJECT_PROXY_SERVER=""
IS_SERVER_MODE=0
IS_SERVER_ALL_MODE=0
PROJECT_DEF_FILE=".repo/manifests/default.xml"
CMD_LINE=""

LOG_INFO="1"
LOG_DEBUG="1"
LOG_ERORR="1"
LOG_FUNCTION="0"



function logd ()
{
  if [ "${LOG_DEBUG}" == "1" ]; then
    echo "$@" | sed "s/^/D:/g"
  fi
}

function loge ()
{
  if [ "${LOG_ERORR}" == "1" ]; then
    echo "$@" | sed "s/^/E:/g"
  fi
}

function logi ()
{
  if [ "${LOG_INFO}" == "1" ]; then
    echo "$@" | sed "s/^/I:/g"
  fi
}

function logf ()
{
  if [ "${LOG_FUNCTION}" == "1" ]; then
    echo "$@" | sed "s/^/FUNC:/g"
  fi
}

function failed ()
{
  loge "$1: exit code $2"
  exit $2
}

function parser_param()
{
  while [ $# -ge 1 ]; do 
    CMD_STR=$1

    # Project manifests file.
    temp=`echo $CMD_STR | grep "^FILE="`
    if [ "$?" == "0" ]; then
      PROJECT_DEF_FILE=`echo $CMD_STR | sed "s/^FILE=//g"`
      logi "使用者指定Manifests File:${PROJECT_DEF_FILE}"
      shift
      continue
    fi

    temp=`echo $CMD_STR | grep "^USE_SYS_PROXY$"`
    if [ "$?" == "0" ]; then
      PROJECT_PROXY_SERVER=`echo $http_proxy | sed "s/.*\/\///g" | sed "s/\/.*//g"`
      logi "使用Proxy server:${PROJECT_PROXY_SERVER}"

      export GIT_PROXY_COMMAND=$MY_PWD/proxy-wrapper
      echo "#!/bin/bash" > $MY_PWD/proxy-wrapper
      echo "# Create by Jack989 script program. " >> $MY_PWD/proxy-wrapper
      echo "nc -x${PROJECT_PROXY_SERVER} -Xconnect \$*" >> $MY_PWD/proxy-wrapper
      chmod 777 $MY_PWD/proxy-wrapper
      shift
      continue
    fi

    temp=`echo $CMD_STR | grep "^SERVER_MODE$"`
    if [ "$?" == "0" ]; then
      logi "設定為Server Project模式"
      IS_SERVER_MODE=1
      shift
      continue
    fi

    temp=`echo $CMD_STR | grep "^SERVER_ALL_PROJECT$"`
    if [ "$?" == "0" ]; then
      logi "設定為Server All Project模式"
      IS_SERVER_ALL_MODE=1
      shift
      continue
    fi

    logi "執行指令：$@"
    CMD_LINE=$@
    break
  done
}

function run_all_proj()
{
  local project_list=`cat $PROJECT_DEF_FILE | grep "<project" `
  local PROJ_COUNT=`echo "${project_list}" | wc -l | sed "s/ .*//g"`
  local IDX=1

  # run project command
  while [ $PROJ_COUNT -ge $IDX ]; do 

    local PROJ_INFO=`echo "${project_list}" | sed -n "${IDX},${IDX}p"`
    local have_find_path=`echo $PROJ_INFO | grep "path=" | wc -l | sed "s/ .*//g"`
    local have_find_name=`echo $PROJ_INFO | grep "name=" | wc -l | sed "s/ .*//g"`
    logi "-----------------------------------------------------"
    logd "IDX=${IDX}"
    logd "PROJ_INFO=${PROJ_INFO}"
    logd "have_find_path=${have_find_path} have_find_name=${have_find_name}"
    local proj_path=""
    if [ "${have_find_path}" == "0" ]; then
      local proj_path=""
    else
      local proj_path=`echo $PROJ_INFO | sed "s/.*path=\"//g" | sed "s/\".*//g"`
    fi

    local proj_name=`echo $PROJ_INFO | sed "s/.*name=\"//g" | sed "s/\".*//g"`
    logd "name=${proj_name}"
    logd "path=${proj_path}"
    local proj_dir=""
    export ANDROID_PROJ_NAME=$proj_name
    export ANDROID_PROJ_PATH=$proj_path

    if [ "${IS_SERVER_MODE}" == "1" ]; then
      proj_dir="${proj_name}.git"
    else
      proj_dir="${proj_path}"
      if [ "${have_find_path}" == "0" ]; then
        proj_dir="${proj_name}"
      fi
    fi

    logi "Project: ${proj_dir}"
    if [ ! -e "$MY_PWD/${proj_dir}" ]; then
      loge "此目錄不存在:${proj_dir}"
    else
      cd "$MY_PWD/${proj_dir}"
      my_log=`$CMD_LINE`
      logi "$my_log"
    fi

    IDX=$(($IDX + 1))
  done

}

function run_server_all_proj()
{
  local project_list=`find -path "*\.git" | sed "s/^\.\///g"`
  logd "project_list:${project_list}"
  local PROJ_COUNT=`echo "${project_list}" | wc -l | sed "s/ .*//g"`
  local IDX=1

  # run project command
  for PROJ_INFO in ${project_list}
  do
    logi "-----------------------------------------------------"
    logd "IDX=${IDX}"
    logd "PROJ_INFO=${PROJ_INFO}"

    export ANDROID_PROJ_PATH=$PROJ_INFO

    logi "Project: ${PROJ_INFO}"
    if [ ! -e "$MY_PWD/${PROJ_INFO}" ]; then
      loge "此目錄不存在:${PROJ_INFO}"
    else
      cd "$MY_PWD/${PROJ_INFO}"
      my_log=`$CMD_LINE`
      logi "$my_log"
    fi

    IDX=$(($IDX + 1))
  done
}

function main()
{
  parser_param $@

  if [ "${IS_SERVER_ALL_MODE}" == "0" ]; then
    run_all_proj
  elif [ "${IS_SERVER_ALL_MODE}" == "1" ]; then
    run_server_all_proj
  fi

  cd $MY_PWD
}

main $@




