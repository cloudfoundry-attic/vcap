#!/bin/bash
set +v 

function set_proxy {
	[ -z PROXY_URL ] && return
	echo "Setting proxy ..."
	export http_proxy=$PROXY_URL
	export https_proxy=$PROXY_URL
	export no_proxy=localhost,127.0.0.1
}
function unset_proxy {
	echo "Unsetting proxy ..."
	export http_proxy=
	export https_proxy=
	export no_proxy=
}
function add_repo {
	[ -z REPOSITORY_URL ] && return
	CNT=0
	(IFS=,
	for URL in $REPOSITORY_URL; do
		CNT=$((CNT+1))
		zypper ar $URL temp_repo$CNT
	done)
}
function del_repo {
	[ -z REPOSITORY_URL ] && return
	CNT=0
	(IFS=,
	for URL in $REPOSITORY_URL; do
		CNT=$((CNT+1))
		zypper rr temp_repo$CNT
	done)
}

REPOSITORY_URL=
PROXY_URL=

usage()
{
cat << EOF
usage: $0 options

This script downloads and packages CloudFoundry binaries.

OPTIONS:
   -h|--help         Show this message
   -r|--repo         A comma separated list of repository urls for required rpms (optional) ex. "http://repo1/rpms,http://repo2/rpms"
   -p|--proxy        The proxy url for internet access if any (optional) ex. http://proxy:8080/
EOF
exit 0
}

for arg
do
    delim=""
    case "$arg" in
       --help) args="${args}-h ";;
       --repo) args="${args}-r ";;
	   --proxy) args="${args}-p ";;
       # pass through anything else
       *) [[ "${arg:0:1}" == "-" ]] || delim="\""
           args="${args}${delim}${arg}${delim} ";;
    esac
done

# reset the translated args
eval set -- $args
# now we can process with getopt
while getopts ":hr:p:" opt; do
    case $opt in
        h)  usage ;;
        r)  REPOSITORY_URL=$OPTARG ;;
		p)	PROXY_URL=$OPTARG ;;
        \?) usage ;;
        :)
        usage
        ;;
    esac
done

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or using sudo!" 1>&2
   exit 1
fi

echo "Adding repository for git installation: $REPOSITORY_URL ..."
add_repo
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

echo "Installing Git ..."
zypper --no-gpg-checks --non-interactive install -l --force --force-resolution --no-recommends git
[ $? -eq 0 ] && echo SUCCESS
if [ $? -ne 0 ] 
then
	del_repo
	echo "If you have missing dependencies in your installation go to http://software.opensuse.org and add the necessary repositories."
	exit 1
fi

echo "Removing repository for git installation: $REPOSITORY_URL ..."
del_repo
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

set_proxy
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Syncing Cloudfoundry from Git ..."
git clone https://github.com/cloudfoundry/vcap.git
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

pushd vcap
echo "Syncing subrepositories like services ..."
git submodule update --init
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

unset_proxy
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Creating archive for the common components ..."
tar -vzcf ../vcap_common.tar.gz bin/vcap common/ lib/ rakelib/ Rakefile .rvmrc
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Creating archive for Router ..."
tar -vzcf ../vcap_router.tar.gz bin/router router/ setup/simple.nginx.conf
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Creating archive for DEA ..."
tar -vzcf ../vcap_dea.tar.gz bin/dea dea/
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Creating archive for Cloud Controller ..."
tar -vzcf ../vcap_cloud_controller.tar.gz bin/cloud_controller cloud_controller/
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Creating archive for Health manager ..."
tar -vzcf ../vcap_health_manager.tar.gz bin/health_manager health_manager/
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Creating archive for Services ..."
tar -vzcf ../vcap_services.tar.gz bin/services/ services/
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
popd
echo "All operations completed Successfully!"