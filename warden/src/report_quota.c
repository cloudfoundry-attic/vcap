#include <assert.h>
#include <errno.h>
#include <fstab.h>
#include <inttypes.h>
#include <malloc.h>
#include <mntent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/quota.h>

/**
 * Attempts to look up the device name associated with supplied mount point.
 *
 * @param dir      Mount point to look up
 * @param dev_name Where to place the device name. Caller must free.
 *
 * @return         0 on success
 *                -1 mount point not found
 *                -2 cannot open mtab
 */
static int lookup_device(const char* dir, char** dev_name) {
  FILE* mtab                = NULL;
  struct mntent* mtab_entry = NULL;
  size_t fsname_len         = 0;
  int retval                = -1;

  assert(NULL != dir);
  assert(NULL != dev_name);

  if (NULL == (mtab = setmntent(_PATH_MOUNTED, "r"))) {
    return -2;
  }

  while (NULL != (mtab_entry = getmntent(mtab))) {
    if (!strcmp(mtab_entry->mnt_dir, dir)) {
      fsname_len = strlen(mtab_entry->mnt_fsname) + 1;

      *dev_name = malloc(fsname_len);
      assert(NULL != *dev_name);

      strncpy(*dev_name, mtab_entry->mnt_fsname, fsname_len);
      retval = 0;
      break;
    }
  }

  endmntent(mtab);

  return retval;
}

/**
 * Attempts to print a helpful error message to stderr.
 *
 * @param msg Error message to prepend.
 */
static void print_quotactl_error(const char* msg) {
  assert(NULL != msg);

  switch (errno) {
    case EFAULT:
      fprintf(stderr, "%s: Block device invalid.\n", msg);
      break;

    case ENOENT:
      fprintf(stderr, "%s: Block device doesn't exist.\n", msg);
      break;

    case ENOSYS:
      fprintf(stderr, "%s: Kernel doesn't haven quota support.\n", msg);
      break;

    case ENOTBLK:
      fprintf(stderr, "%s: Not a block device.\n", msg);
      break;

    case EPERM:
      fprintf(stderr, "%s: Insufficient privilege.\n", msg);
      break;

    case ESRCH:
      fprintf(stderr, "%s: No quota for supplied user.\n", msg);
      break;

    default:
      perror(msg);
      break;
  }
}

/**
 * Prints relevant quota information to stdout for the supplied uid.
 * On failure, will attempt to print a helpful error messge to stderr.
 *
 * @param filesystem  Filesystem to report quota information for
 * @param uid         Uid to report quota information for
 *
 * @return            -1 on error, 0 otherwise
 */
static int print_quota_usage(const char* filesystem, int uid) {
  assert(NULL != filesystem);

  char emsg[1024];
  struct dqblk quota_info;

  memset(&quota_info, 0, sizeof(quota_info));

  if (quotactl(QCMD(Q_GETQUOTA, USRQUOTA), filesystem, uid, (caddr_t) &quota_info) < 0) {
    sprintf(emsg, "Failed retrieving quota for uid=%d", uid);
    print_quotactl_error(emsg);
    return -1;
  }

  printf("%d ", uid);

  /* Block info */
  printf("%llu %llu %llu %llu ",
         (long long unsigned int) quota_info.dqb_curspace / 1024,
         (long long unsigned int) quota_info.dqb_bsoftlimit,
         (long long unsigned int) quota_info.dqb_bhardlimit,
         (long long unsigned int) quota_info.dqb_btime);

  /* Inode info */
  printf("%llu %llu %llu %llu\n",
         (long long unsigned int) quota_info.dqb_curinodes,
         (long long unsigned int) quota_info.dqb_isoftlimit,
         (long long unsigned int) quota_info.dqb_ihardlimit,
         (long long unsigned int) quota_info.dqb_itime);

  return 0;
}

int main(int argc, char* argv[]) {
  char* filesystem  = NULL;
  char* device_name = NULL;
  char** uid_strs   = NULL;
  int* uids         = NULL;
  int num_uids      = 0;
  int ii            = 0;

  if (argc < 3) {
    printf("Usage: report_quota [filesystem] [uid]+\n");
    printf("Reports quota information for the supplied uids on the given filesystem\n");
    printf("Format is: <uid> <blocks used> <soft> <hard> <grace> <inodes used> <soft> <hard> <grace>\n");
    exit(1);
  }

  filesystem = argv[1];
  num_uids   = argc - 2;
  uid_strs   = argv + 2;

  if (lookup_device(argv[1], &device_name) < 0) {
    printf("Couldn't find device for %s\n", argv[1]);
    exit(1);
  }

  uids = malloc(sizeof(*uids) * num_uids);
  assert(NULL != uids);

  memset(uids, 0, sizeof(*uids) * num_uids);
  for (ii = 0; ii < num_uids; ii++) {
    uids[ii] = atoi(uid_strs[ii]);
  }

  for (ii = 0; ii < num_uids; ii++) {
    if (print_quota_usage(device_name, uids[ii]) < 0) {
      exit(1);
    }
  }

  /* Pedantry! */
  free(device_name);
  free(uids);

  return 0;
}
