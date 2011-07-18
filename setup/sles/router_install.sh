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
	URL=$1
	zypper ar $URL chef_repo
}
function del_repo {
	zypper rr chef_repo
}


REPOSITORY_URL=
PROXY_URL=
PACKAGE_URL=
MESSAGE_BUS=

usage()
{
cat << EOF
usage: $0 options

This script downloads and packages CloudFoundry binaries.

OPTIONS:
   -h|--help         Show this message
   -r|--repo         Repository url for git rpms
   -p|--proxy		 The proxy url for internet access if any (optional) ex. http://proxy:8080/
   -a|--archive		 The archive package url (for local packages use file:///path/file)
   -m|--mbus		 The URL of the messagebus ex. "10.68.32.11:4222"
EOF
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
if [[ -z $REPOSITORY_URL ]] || [[ -z $PACKAGE_URL ]] || [[ -z $MESSAGE_BUS ]]
then
     usage
     exit 1
fi

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or using sudo!" 1>&2
   exit 1
fi

echo "Adding repository for git installation: $REPOSITORY_URL ..."
add_repo $REPOSITORY_URL
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

cd /opt/cloudfoundry
rvm use 1.9.2
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
gem pristine --all
rake bundler:install

echo "Modifying /home/cloudfoundry/router/config/router.yml to change mbus to ip address of the cloud controller node ..."
sed -i "s/^.*mbus.*$/mbus: nats:\/\/$MESSAGE_BUS/" router/config/router.yml

bin/vcap start 
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

echo "All operations completed Successfully!"