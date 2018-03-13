Backup Btrfs tool
=================

Overview
--------
This is a tool group that perform differential backup in the environment using Btrfs.
It consists of a backup daemon and a client, and can send backups not only to local host but also remote hosts.

Contents
--------
* `backup_btrfs.sh`:  
  Backup client script.
  If backups are sent to remote hosts, it uses `ssh` command.
  This script has 3 arguments of `-c`, `-C`, and `-u`.
  `-c` is an option of directory path for communication with backup daemon of `backup_btrfsd.sh`.
  `-C` is an option of path of configuration file.
  `-u` is an option of user when this script uses `ssh` command.
* `backup_btrfsd.sh`:  
  Backup daemon script.
  It should be run on a host computer that receives backups.
  This script has 2 arguments of `-c` and `-g`.
  `-c` is an option of directory path for communication with backup client of `backup_btrfs.sh`.
  `-g` is an option of group that be permitted connecting backup daemon,
* `backup_btrfs-redirect_helper.sh`:  
  Helper script used by `backup_btrfs.sh`.
  Host computers receiving backups installs this script.

Configuration file
------------------
A configuration file loaded by client script has 3 contents to be set.
`BACKUP_SRC_LIST` is a list of backup source paths.
These paths must be absolute path and top layer of btrfs subvolume.
`BACKUP_TGT_LIST` is a list of backup target paths.
If target paths is on remote hosts, the format of path is as follows:
"ssh://_user_@_hostname_//path/to/target".
`NUM_HOLD_BACKUPS` is the number of backups that are held.

Requirement
-----------
* btrfs-progs (`btrfs` command)
* inotify-tools (`inotifywait` command)

Install
-------
`*.sh` that are contented of and `libbackup_btrfs.d` are installed in the same directory of `PATH`.

License
-------
This tool is released under the GPLv3 license.
Please see LICENSE file for details.

