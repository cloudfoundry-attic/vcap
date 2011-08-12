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
CC_NAME=
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
   -c|--ccurl        The external URL of the Cloud Controller ex. api.vcap.me 
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
	   --mbus)	args="${args}-m ";;
	   --ccurl)	args="${args}-c ";;
       # pass through anything else
       *) [[ "${arg:0:1}" == "-" ]] || delim="\""
           args="${args}${delim}${arg}${delim} ";;
    esac
done

# reset the translated args
eval set -- $args
# now we can process with getopt
while getopts ":hr:a:p:m:c:" opt; do
    case $opt in
        h)  usage ;;
        r)  REPOSITORY_URL=$OPTARG ;;
		p)	PROXY_URL=$OPTARG ;;
		a)	PACKAGE_URL=$OPTARG ;;
		m)	MESSAGE_BUS=$OPTARG ;;
		c)	CC_NAME=$OPTARG ;;
        \?) usage ;;
        :)
        usage
        ;;
    esac
done
if [[ -z $PACKAGE_URL ]] || [[ -z $MESSAGE_BUS ]] || [[ -z $CC_NAME ]]
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

zypper --no-gpg-checks --non-interactive install -l --force --force-resolution --no-recommends ruby-devel ruby-mysql libmysqlclient-devel mysql rabbitmq-server redis
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
cd  /opt/cloudfoundry/
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

set_proxy
pushd services/rabbit/vendor/cache
gem install * --no-rdoc --no-ri
popd
echo "Installing MongoDB ..."
export MONGODB_VERSION=1.8.1
export mongodb="mongodb-linux-x86_64-$MONGODB_VERSION"
wget http://fastdl.mongodb.org/linux/$mongodb.tgz
unset_proxy
tar -zxvf $mongodb.tgz
cp $mongodb/bin/* /usr/bin
rm $mongodb.tgz
rm -fr $mongodb
gem pristine --all
[ $? -ne 0 ] && exit 1
rake bundler:install
[ $? -ne 0 ] && exit 1
cat << EOF
- For each file on /home/cloudfoundry/services/[mongodb|mysql|redis|rabbitmq]/config/[mongodb|mysql|redis|rabbitmq]_gateway.yml, change [mongodb|redis|rabbitmq|mysql]_mbus, service_mbus to ip address of your cloud controller. Also change cloud_controller_uri to your domain name installation
mysql_mbus: nats://10.30.1.4:4222
service_mbus: nats://10.30.1.4:4222
cloud_controller_uri : api.passform.com
- For each file on /home/cloudfoundry/services/[mongodb|mysql|redis|rabbitmq]/config/[mongodb|mysql|redis|rabbitmq]_node.yml, change mbus to ip address of your cloud controller. Dont forget to change your MySQL root password on mysql_node.yml. And also change cloud_controller_uri to your domain name installation
cloud_controller_uri : api.passform.com
mbus: nats://10.30.1.4:4222
EOF

SERVICES="mongodb mysql redis rabbit"
for VAR in $SERVICES
do
	sed -i "s/^.*cloud_controller_uri.*$/cloud_controller_uri : $CC_NAME/" services/$VAR/config/${VAR}_gateway.yml
	sed -i "s/^.*${VAR}_mbus.*$/${VAR}_mbus: nats:\/\/$MESSAGE_BUS/" services/$VAR/config/${VAR}_gateway.yml
	sed -i "s/^.*service_mbus.*$/services_mbus: nats:\/\/$MESSAGE_BUS/" services/$VAR/config/${VAR}_gateway.yml
	
	sed -i "s/^.*mbus.*$/mbus: nats:\/\/$MESSAGE_BUS/" services/$VAR/config/${VAR}_node.yml
	sed -i "s/^.*cloud_controller_uri.*$/cloud_controller_uri : $CC_NAME/" services/$VAR/config/${VAR}_node.yml
done

sed -i "s/^.*pass:.*$/  pass:/" services/mysql/config/mysql_node.yml

service mysql start
[ $? -ne 0 ] && exit 1
service rabbitmq-server start
[ $? -ne 0 ] && exit 1
service redis start
[ $? -ne 0 ] && exit 1
bin/vcap start 
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

echo "All operations completed Successfully!"