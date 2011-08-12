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

RVM=/usr/local/bin/rvm
REPOSITORY_URL=
PROXY_URL=
MESSAGE_BUS=
EXT_URI=
PACKAGE1_URL=
PACKAGE2_URL=
RUBY192=1.9.2-p180

usage()
{
cat << EOF
usage: $0 options

This script downloads and packages CloudFoundry binaries.

OPTIONS:
   -h|--help         Show this message
   -r|--repo         A comma separated list of repository urls for required rpms (optional) ex. "http://repo1/rpms,http://repo2/rpms"
   -p|--proxy        The proxy url for internet access if any (optional) ex. http://proxy:8080/
   -c|--carch        The archive package url of Cloud controller (for local packages use file:///path/file)
   -e|--earch        The archive package url of Health manager (for local packages use file:///path/file)
   -m|--mbus         The URL of the messagebus ex. "10.68.32.11:4222"
   -u|--exturl       The external URL of the Cloudfoundry instance(usually the one where the router is installed) ex. api.vcap.me
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
	   --carch) args="${args}-c ";;
	   --earch) args="${args}-e ";;
	   --mbus)	args="${args}-m ";;
	   --exturl) args="${args}-u ";;
       # pass through anything else
       *) [[ "${arg:0:1}" == "-" ]] || delim="\""
           args="${args}${delim}${arg}${delim} ";;
    esac
done

# reset the translated args
eval set -- $args
# now we can process with getopt
while getopts ":hr:c:e:p:m:u:" opt; do
    case $opt in
        h)  usage ;;
        r)  REPOSITORY_URL=$OPTARG ;;
		p)	PROXY_URL=$OPTARG ;;
		c)	PACKAGE1_URL=$OPTARG ;;
		e)	PACKAGE2_URL=$OPTARG ;;
		m)	MESSAGE_BUS=$OPTARG ;;
		u)	EXT_URI=$OPTARG ;;
        \?) usage ;;
        :)
        usage
        ;;
    esac
done
if [[ -z $PACKAGE1_URL ]] || [[ -z $PACKAGE2_URL ]] || [[ -z $MESSAGE_BUS ]] || [[ -z $EXT_URI ]]
then
     usage
fi

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or using sudo!" 1>&2
   exit 1
fi

echo "Adding repository for git installation: $REPOSITORY_URL ..."
add_repo
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

zypper --no-gpg-checks --non-interactive install -l --force --force-resolution --no-recommends postgresql postgresql-server rubygem-postgres postgresql-libs rubygem-pg postgresql-devel
[ $? -eq 0 ] && echo SUCCESS
if [ $? -ne 0 ] 
then
	del_repo
	echo "If you have missing dependencies in your installation go to http://software.opensuse.org and add the necessary repositories."
	exit 1
fi
del_repo
set_proxy

# Sourcing RVM just in case
#source /etc/profile.d/rvm.sh
cd /opt/cloudfoundry/
if [[ $PACKAGE1_URL =~ (/([^/]*)$) ]]; then
     PACKAGE1_NAME=`echo ${BASH_REMATCH[2]}`
fi
curl -o $PACKAGE1_NAME $PACKAGE1_URL
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Extracting common archive ..."
tar -vzxf $PACKAGE1_NAME
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
rm $PACKAGE1_NAME

$RVM use $RUBY192
[ $? -ne 0 ] && exit 1
gem install pg -v 0.10.1 --no-rdoc --no-ri
pushd cloud_controller/vendor/cache
gem install * --no-rdoc --no-ri
popd
gem pristine --all
[ $? -ne 0 ] && exit 1
#in case of problems with rake use - "bundle exec rake bundler:install"
rake bundler:install
[ $? -ne 0 ] && exit 1
echo "Editing cloud_controller/config/cloud_controller.yml to change local_route to ip address of the node, change the domain name of your installation and mbus configuration ..."
sed -i "s/^.*local_route.*$/local_route: `hostname -i`/" cloud_controller/config/cloud_controller.yml
sed -i "s/^.*external_uri.*$/external_uri : $EXT_URI/" cloud_controller/config/cloud_controller.yml
sed -i "s/^.*mbus.*$/mbus: nats:\/\/$MESSAGE_BUS/" cloud_controller/config/cloud_controller.yml
# cd cloud_controller; bundle exec rake db:migrate; cd .. # in case db is not created as expected

bin/vcap start
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

if [[ $PACKAGE2_URL =~ (/([^/]*)$) ]]; then
     PACKAGE2_NAME=`echo ${BASH_REMATCH[2]}`
fi
curl -o $PACKAGE2_NAME $PACKAGE2_URL
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Extracting common archive ..."
tar -vzxf $PACKAGE2_NAME
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
rm $PACKAGE2_NAME
bundle exec rake bundler:install
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

echo "Editing /home/cloudfoundry/health_manager/config/health_manager.yml to change local_route to ip address of the node and change mbus to ip address of your cloud controller node"
sed -i "s/^.*local_route.*$/local_route: `hostname -i`/" health_manager/config/health_manager.yml
sed -i "s/^.*mbus.*$/mbus: nats:\/\/$MESSAGE_BUS/" health_manager/config/health_manager.yml

bin/vcap start
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
unset_proxy
echo "All operations completed Successfully!"