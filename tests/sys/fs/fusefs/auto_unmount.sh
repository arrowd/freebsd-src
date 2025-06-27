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
	atf_check [ "$(cat mnt/hello)" == "Hello World!" ]
}
common_cleanup()
{
	killall fuse-hello_ll || true
	umount $PWD/mnt || true
	atf_check -s exit:1 pgrep fuse-hello_ll
	check_not_mounted
}


atf_test_case no_auto_unmount_normal_exit cleanup
no_auto_unmount_normal_exit_head()
{
	atf_set "descr" "Checks that the FUSE daemon performs an unmount on its own"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll" # filesystems/fusefs-hello_ll
}
no_auto_unmount_normal_exit_body()
{
	atf_check mkdir mnt
	atf_check fuse-hello_ll mnt
	check_hello
	atf_check killall fuse-hello_ll
	sleep 1
	check_not_mounted
}
no_auto_unmount_normal_exit_cleanup()
{
	common_cleanup
}


atf_test_case no_auto_unmount_abnormal_exit cleanup
no_auto_unmount_abnormal_exit_head()
{
	atf_set "descr" "Checks that the FUSE mount lingers if daemon exits abnormally"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
no_auto_unmount_abnormal_exit_body()
{
	atf_check mkdir mnt
	atf_check fuse-hello_ll mnt
	check_hello
	atf_check killall -KILL fuse-hello_ll
	sleep 1
	check_mounted
}
no_auto_unmount_abnormal_exit_cleanup()
{
	common_cleanup
}


atf_test_case no_auto_unmount_external_unmount cleanup
no_auto_unmount_external_unmount_head()
{
	atf_set "descr" "Checks that unmounting via umount works when auto_unmount is disabled"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
no_auto_unmount_external_unmount_body()
{
	atf_check mkdir mnt
	atf_check fuse-hello_ll mnt
	check_hello
	atf_check umount mnt
	sleep 1
	check_not_mounted
}
no_auto_unmount_external_unmount_cleanup()
{
	common_cleanup
}


atf_test_case auto_unmount_normal_exit cleanup
auto_unmount_normal_exit_head()
{
	atf_set "descr" "Checks that the FUSE daemon performs an unmount on its own even if auto_unmount is enabled"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
auto_unmount_normal_exit_body()
{
	atf_check mkdir mnt
	atf_check fuse-hello_ll -o auto_unmount mnt
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
	atf_set "descr" "Checks that the FUSE mount gets unmounted if daemon exits abnormally and auto_unmount is enabled"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
auto_unmount_abnormal_exit_body()
{
	atf_check mkdir mnt
	atf_check fuse-hello_ll -o auto_unmount mnt
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
	atf_set "descr" "Checks that unmounting via umount works when auto_unmount is enabled"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
auto_unmount_external_unmount_body()
{
	atf_check mkdir mnt
	atf_check fuse-hello_ll -o auto_unmount mnt
	check_hello
	atf_check umount mnt
	sleep 1
	check_not_mounted
}
auto_unmount_external_unmount_cleanup()
{
	common_cleanup
}


atf_test_case auto_unmount_no_double_unmount cleanup
auto_unmount_no_double_unmount_head()
{
	atf_set "descr" "Checks that enabling auto_unmount does not cause double unmount on SIGINT"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
auto_unmount_no_double_unmount_body()
{
	atf_check mkdir mnt
	atf_check fuse-hello_ll mnt
	check_hello
	atf_check fuse-hello_ll -o auto_unmount mnt
	check_hello
	# we have two daemons running
	atf_check [ $(pgrep hello_ll | wc -l) = 2 ]
	hello_with_auto_unmount_pid=$(pgrep -lf hello_ll | grep auto_unmount | awk '{print $1}')
	atf_check [ ! -z "$hello_with_auto_unmount_pid" ]
	atf_check kill $hello_with_auto_unmount_pid
	sleep 1
	# the second daemon auto-unmounted itself, but the first one
	# should continue running
	check_hello
}
auto_unmount_no_double_unmount_cleanup()
{
	common_cleanup
}


atf_test_case auto_unmount_no_double_unmount_external cleanup
auto_unmount_no_double_unmount_external_head()
{
	atf_set "descr" "Checks that enabling auto_unmount does not cause double unmount when unmounting via umount"
	atf_set "require.user" "root"
	atf_set "require.progs" "fuse-hello_ll"
}
auto_unmount_no_double_unmount_external_body()
{
	atf_check mkdir mnt
	atf_check fuse-hello_ll mnt
	check_hello
	atf_check fuse-hello_ll -o auto_unmount mnt
	check_hello
	# we have two daemons running
	atf_check [ $(pgrep hello_ll | wc -l) = 2 ]
	atf_check umount mnt
	sleep 1
	# the second daemon auto-unmounted itself, but the first one
	# should continue running
	check_hello
}
auto_unmount_no_double_unmount_external_cleanup()
{
	common_cleanup
}


atf_init_test_cases()
{
	atf_add_test_case no_auto_unmount_normal_exit
	atf_add_test_case no_auto_unmount_abnormal_exit
	atf_add_test_case no_auto_unmount_external_unmount
	atf_add_test_case auto_unmount_normal_exit
	atf_add_test_case auto_unmount_abnormal_exit
	atf_add_test_case auto_unmount_external_unmount
	atf_add_test_case auto_unmount_no_double_unmount
	atf_add_test_case auto_unmount_no_double_unmount_external
	# auto_unmount + usermount combo is tested in usermount.sh
}
