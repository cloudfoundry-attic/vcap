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
PACKAGE_URL=
MESSAGE_BUS=
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
   -a|--archive      The archive package url (for local packages use file:///path/file)
   -m|--mbus         The URL of the messagebus ex. "10.68.32.11:4222"
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
	   --archive) args="${args}-a ";;
	   --mbus) args="${args}-m ";;
       # pass through anything else
       *) [[ "${arg:0:1}" == "-" ]] || delim="\""
           args="${args}${delim}${arg}${delim} ";;
    esac
done

# reset the translated args
eval set -- $args
# now we can process with getopt
while getopts ":hr:a:p:m:" opt; do
    case $opt in
        h)  usage ;;
        r)  REPOSITORY_URL=$OPTARG ;;
		p)	PROXY_URL=$OPTARG ;;
		a)	PACKAGE_URL=$OPTARG ;;
		m)	MESSAGE_BUS=$OPTARG ;;
        \?) usage ;;
        :)
        usage
        ;;
    esac
done
if [[ -z $PACKAGE_URL ]] || [[ -z $MESSAGE_BUS ]]
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

zypper --no-gpg-checks --non-interactive install -l --force --force-resolution --no-recommends nginx
[ $? -eq 0 ] && echo SUCCESS
if [ $? -ne 0 ] 
then
	del_repo
	echo "If you have missing dependencies in your installation go to http://software.opensuse.org and add the necessary repositories."
	exit 1
fi
del_repo
# Sourcing RVM just in case
#source /etc/profile.d/rvm.sh
cd /opt/cloudfoundry
$RVM use $RUBY192
if [[ $PACKAGE_URL =~ (/([^/]*)$) ]]; then
     PACKAGE_NAME=`echo ${BASH_REMATCH[2]}`
fi
curl -o $PACKAGE_NAME $PACKAGE_URL
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Extracting common archive ..."
tar -vzxf $PACKAGE_NAME
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
rm $PACKAGE_NAME
cp setup/simple.nginx.conf /etc/nginx/nginx.conf
sed -i "s/^.*user www-data.*$/user root;/" /etc/nginx/nginx.conf
service nginx restart
pushd router/vendor/cache
gem install * --no-rdoc --no-ri
popd
gem pristine --all
[ $? -ne 0 ] && exit 1
rake bundler:install
[ $? -ne 0 ] && exit 1
echo "Modifying /home/cloudfoundry/router/config/router.yml to change mbus to ip address of the cloud controller node ..."
sed -i "s/^.*mbus.*$/mbus: nats:\/\/$MESSAGE_BUS/" router/config/router.yml

bin/vcap start 
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

echo "All operations completed Successfully!"