# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Gleb Popov <arrowd@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS DOCUMENTATION IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


check_mounted()
{
	atf_check [ ! -z "$(mount | grep fuse-hello_ll)" ]
}
check_not_mounted()
{
	atf_check [ -z "$(mount | grep fuse-hello_ll)" ]
}
check_hello()
{
	check_mounted
	atf_check [ "$(su -m nobody -c 'cat mnt/hello')" == "Hello World!" ]
}
common_cleanup()
{
	killall fuse-hello_ll || true
	umount $PWD/mnt || true
	atf_check -s exit:1 pgrep fuse-hello_ll
	check_not_mounted
}


atf_test_case usermount cleanup
usermount_head()
{
	atf_set "descr" "Checks that mounting a FUSE filesystem as a regular user using the usermount functionality works"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll" # filesystems/fusefs-hello_ll
}
usermount_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check su -m nobody -c "fuse-hello_ll mnt"
	check_hello
	# check that usermount always mounts with nosuid
	atf_check [ ! -z "$(mount | grep fuse-hello_ll | grep nosuid)" ]
}
usermount_cleanup()
{
	common_cleanup
}


atf_test_case usermount_negative_cases cleanup
usermount_negative_cases_head()
{
	atf_set "descr" "Checks cases when usermounting is not allowed"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
usermount_negative_cases_body()
{
	atf_check -s exit:1 -e match:"bad mount point" \
		su -m nobody -c "fuse-hello_ll /non/exist/ent"
	check_not_mounted

	atf_check mkdir d
	atf_check chown nobody d
	atf_check su -m nobody -c "touch d/file"
	atf_check -s exit:1 -e match:"Not a directory" \
		su -m nobody -c "fuse-hello_ll d/file"
	check_not_mounted

	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check chmod -x mnt
	atf_check -s exit:1 -e match:"failed to chdir into mountpoint" \
		su -m nobody -c "fuse-hello_ll mnt"
	check_not_mounted
	atf_check rmdir mnt

	atf_check mkdir mnt
	atf_check chown tests mnt
	# if we aren't owner, having sticky bit is not acceptable
	atf_check chmod 0777 mnt
	atf_check chmod +t mnt
	atf_check -s exit:1 -e match:"mountpoint .* not owned by user" \
		su -m nobody -c "fuse-hello_ll mnt"
	check_not_mounted
	atf_check rmdir mnt

	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check chmod -w mnt
	atf_check -s exit:1 -e match:"no write access to mountpoint" \
		su -m nobody -c "fuse-hello_ll mnt"
	check_not_mounted
	atf_check rmdir mnt

	atf_check mkdir mnt
	atf_check mount -t tmpfs tmpfs mnt
	atf_check mkdir mnt/dir
	atf_check chown -R nobody mnt
	atf_check -s exit:1 -e match:"mounting over filesystem type tmpfs is forbidden" \
		su -m nobody -c "env MOUNT_FUSEFS_TESTING=1 fuse-hello_ll mnt/dir"
	check_not_mounted
	atf_check umount mnt
	atf_check rmdir mnt

	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check -s exit:1 -e match:"usage is disallowed for usermount" \
		su -m nobody -c "fuse-hello_ll -o allow_other mnt"
	check_not_mounted

	atf_check -s exit:1 -e match:"usage is disallowed for usermount" \
		su -m nobody -c "fuse-hello_ll -o allow_root mnt"
	check_not_mounted

	atf_check -s exit:1 -e match:"usermount mode, spawning daemon not allowed" \
		su -m nobody -c "mount_fusefs -D `which fuse-hello_ll` /dev/fuse mnt"
	check_not_mounted

	# mounting over another mountpoint is not allowed
	atf_check mount -t tmpfs tmpfs mnt
	atf_check -s exit:1 -e match:"Device busy" \
		su -m nobody -c "fuse-hello_ll mnt"
	check_not_mounted
	atf_check umount mnt

	atf_check touch mnt/file
	atf_check -s exit:1 -e match:"Directory not empty" \
		su -m nobody -c "fuse-hello_ll mnt"
	check_not_mounted
}
usermount_negative_cases_cleanup()
{
	common_cleanup
}


atf_test_case userunmount cleanup
userunmount_head()
{
	atf_set "descr" "Checks that the FUSE daemon can unmount on its own in the usermount mode"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
userunmount_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check su -m nobody -c "fuse-hello_ll mnt"
	check_hello
	# sending INT to the daemon will cause it to shutdown normally
	# and call fuse_session_unmount()
	atf_check killall fuse-hello_ll
	sleep 1
	check_not_mounted
}
userunmount_cleanup()
{
	common_cleanup
}


atf_test_case userunmount_external cleanup
userunmount_external_head()
{
	atf_set "descr" "Checks that unmounting as a regular user works via mount_fusefs -u"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
userunmount_external_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check su -m nobody -c "fuse-hello_ll mnt"
	check_hello
	# unmounting the mountpoint will cause the daemon to shutdown normally
	atf_check su -m nobody -c "mount_fusefs -u mnt"
	sleep 1
	check_not_mounted
}
userunmount_external_cleanup()
{
	common_cleanup
}


atf_test_case userunmount_external_root cleanup
userunmount_external_root_head()
{
	atf_set "descr" "Checks that auto_unmount does not get in the way when unmounting via umount"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
userunmount_external_root_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check su -m nobody -c "fuse-hello_ll mnt"
	check_hello
	# unmounting the mountpoint will cause the daemon to shutdown normally
	atf_check umount mnt
	sleep 1
	check_not_mounted
}
userunmount_external_root_cleanup()
{
	common_cleanup
}


atf_test_case userunmount_negative_cases cleanup
userunmount_negative_cases_head()
{
	atf_set "descr" "Checks cases when userunmounting is not allowed"
	atf_set "require.user" "root"
}
userunmount_negative_cases_body()
{
	atf_check -s exit:1 -e match:"path to unmount specified incorrectly" \
		su -m nobody -c "mount_fusefs -u"

	atf_check -s exit:1 -e match:"failed to access mountpoint" \
		su -m nobody -c "mount_fusefs -u /non/exist/ent"

	mkdir access_denied
	chmod 0700 access_denied
	atf_check -s exit:1 -e match:"failed to access mountpoint" \
		su -m nobody -c "mount_fusefs -u access_denied/."

	atf_check -s exit:1 -e match:"filesystem was mounted by someone else" \
		su -m nobody -c "mount_fusefs -u /dev"

	atf_check -s exit:1 -e match:"unmount flag only makes sense for usermount" \
		mount_fusefs -u /dev

	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check -o ignore sysctl vfs.usermount=1
	atf_check su -m nobody -c "mount -t devfs devfs mnt"
	atf_check -o ignore sysctl vfs.usermount=0
	atf_check -s exit:1 -e match:"refusing to unmount non-FUSE filesystem" \
		su -m nobody -c "mount_fusefs -u mnt"
}
userunmount_negative_cases_cleanup()
{
	sysctl vfs.usermount=0 || true
	common_cleanup
}


atf_test_case rootunmount cleanup
rootunmount_head()
{
	atf_set "descr" "Checks that unmounting as root works"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
rootunmount_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check su -m nobody -c "fuse-hello_ll mnt"
	check_hello
	atf_check umount mnt
	sleep 1
	check_not_mounted
}
rootunmount_cleanup()
{
	common_cleanup
}


atf_test_case auto_unmount_normal_exit cleanup
auto_unmount_normal_exit_head()
{
	atf_set "descr" "Checks that the FUSE daemon can unmount on its own in the usermount mode"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
auto_unmount_normal_exit_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check su -m nobody -c "fuse-hello_ll -o auto_unmount mnt"
	check_hello
	atf_check killall fuse-hello_ll
	sleep 1
	check_not_mounted
}
auto_unmount_normal_exit_cleanup()
{
	common_cleanup
}


atf_test_case auto_unmount_abnormal_exit cleanup
auto_unmount_abnormal_exit_head()
{
	atf_set "descr" "Checks that the FUSE mount gets unmounted if daemon exits abnormally and auto_unmount is enabled in the usermount mode"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
auto_unmount_abnormal_exit_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check su -m nobody -c "fuse-hello_ll -o auto_unmount mnt"
	check_hello
	atf_check killall -KILL fuse-hello_ll
	sleep 1
	check_not_mounted
}
auto_unmount_abnormal_exit_cleanup()
{
	common_cleanup
}


atf_test_case auto_unmount_external_unmount cleanup
auto_unmount_external_unmount_head()
{
	atf_set "descr" "Checks that the FUSE mount gets unmounted if auto_unmount is enabled and mount_fusefs -u is called"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
auto_unmount_external_unmount_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check su -m nobody -c "fuse-hello_ll -o auto_unmount mnt"
	check_hello
	atf_check su -m nobody -c "mount_fusefs -u mnt"
	sleep 1
	check_not_mounted
}
auto_unmount_external_unmount_cleanup()
{
	common_cleanup
}


atf_test_case usermount_under_vfs_usermount cleanup
usermount_under_vfs_usermount_head()
{
	atf_set "descr" "Checks that the usermount mode does not kick in when vfs.usermount=1"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
usermount_under_vfs_usermount_body()
{
	atf_check mkdir mnt
	atf_check chown nobody mnt
	atf_check -o ignore sysctl vfs.usermount=1
	atf_check su -m nobody -c "fuse-hello_ll mnt"
	check_hello
	# it is currently impossible to tell which way the fs got mounted,
	# but it is observable during unmounting
	atf_check -s exit:1 -e match:"unmount flag only makes sense for usermount" \
		su -m nobody -c "mount_fusefs -u mnt"
	atf_check -o ignore sysctl vfs.usermount=0
}
usermount_under_vfs_usermount_cleanup()
{
	sysctl vfs.usermount=0
	common_cleanup
}


atf_init_test_cases()
{
	atf_add_test_case usermount
	atf_add_test_case usermount_negative_cases
	atf_add_test_case userunmount
	atf_add_test_case userunmount_external
	atf_add_test_case userunmount_external_root
	atf_add_test_case userunmount_negative_cases
	atf_add_test_case rootunmount
	atf_add_test_case auto_unmount_normal_exit
	atf_add_test_case auto_unmount_abnormal_exit
	atf_add_test_case auto_unmount_external_unmount
	atf_add_test_case usermount_under_vfs_usermount
}
