#!/bin/bash
set +v 

function set_proxy {
	[ -z PROXY_URL ] && return
	echo "Setting proxy ..."
	export http_proxy=$PROXY_URL
	export https_proxy=$PROXY_URL
	export no_proxy=localhost,127.0.0.1,.wdf.sap.corp
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
#RAKE=/usr/local/rvm/gems/`ls /usr/local/rvm/rubies/ | grep 1.9`/bin/rake
#GEM=/usr/local/rvm/rubies/`ls /usr/local/rvm/rubies/ | grep 1.9`/bin/gem

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

zypper --no-gpg-checks --non-interactive install -l --force --force-resolution --no-recommends sapjvm6 ruby-devel rubygem-rmagick postgresql rubygem-postgres postgresql-libs ruby-mysql libmysqlclient-devel lsof psmisc nodejs
[ $? -eq 0 ] && echo SUCCESS
if [ $? -ne 0 ] 
then
	del_repo
	echo "If you have missing dependencies in your installation go to http://software.opensuse.org and add the necessary repositories."
	exit 1
fi
del_repo
echo "--- Updating java alternatives ..."
update-alternatives --install java java /opt/sapjvm_6/bin/java 1000
[ $? -ne 0 ] && exit 1
update-alternatives --set java /opt/sapjvm_6/bin/java
[ $? -ne 0 ] && exit 1
echo "--- Editting /etc/profile to include java ..."
[ ! -e /etc/profile.local ] && echo "export PATH=\$PATH" >> /etc/profile.local
sed -i '$aexport JAVA_HOME=/opt/sapjvm_6' /etc/profile.local
[ $? -ne 0 ] && exit 1
sed -i '/export PATH/s|$|:/opt/sapjvm_6/bin|' /etc/profile.local
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

# Sourcing RVM just in case
#source /etc/profile.d/rvm.sh
cd /opt/cloudfoundry
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

$RVM use $RUBY192
gem pristine --all
[ $? -ne 0 ] && exit 1
rake bundler:install
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Modifying /home/cloudfoundry/dea/config/dea.yml to change mbus to ip address of the cloud controller node and local_router to ip address of the dea node ..."
sed -i "s/^.*local_route.*$/local_route: `hostname -i`/" dea/config/dea.yml
sed -i "s/^.*mbus.*$/mbus: nats:\/\/$MESSAGE_BUS/" dea/config/dea.yml

bin/vcap start 
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

echo "All operations completed Successfully!"