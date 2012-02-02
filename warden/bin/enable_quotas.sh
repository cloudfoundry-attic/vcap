#!/bin/bash

if [ ${EUID} -ne 0 ]; then
  echo "Sorry you need to be root"
  exit 1
fi

if [ "${#}" -ne 1 ]; then
  echo "Usage: enable_quotas.sh [mount point]"
  exit 1
fi

quota_fs=${1}

mount -o remount,usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0 ${quota_fs}
quotacheck -vgumb ${quota_fs}
quotaon -v ${quota_fs}
