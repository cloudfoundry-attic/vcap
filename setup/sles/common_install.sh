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

RVM=/usr/local/rvm/bin/rvm

REPOSITORY_URL=
PROXY_URL=
PACKAGE_URL=

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
       # pass through anything else
       *) [[ "${arg:0:1}" == "-" ]] || delim="\""
           args="${args}${delim}${arg}${delim} ";;
    esac
done

# reset the translated args
eval set -- $args
# now we can process with getopt
while getopts ":hr:a:p:" opt; do
    case $opt in
        h)  usage ;;
        r)  REPOSITORY_URL=$OPTARG ;;
		p)	PROXY_URL=$OPTARG ;;
		a)	PACKAGE_URL=$OPTARG ;;
        \?) usage ;;
        :)
        usage
        ;;
    esac
done
if [[ -z $REPOSITORY_URL ]] || [[ -z $PACKAGE_URL ]]
then
     usage
     exit 1
fi

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or using sudo!" 1>&2
   exit 1
fi
# set_proxy # only if behind a corporate firewall
echo "Adding repository for git installation: $REPOSITORY_URL ..."
add_repo $REPOSITORY_URL
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
zypper --no-gpg-checks --non-interactive install -l --force --force-resolution --no-recommends ruby rubygems git
zypper --no-gpg-checks --non-interactive install -l --force --force-resolution --no-recommends coreutils autoconf curl bison MyODBC-unixODBC libgio-fam liblzmadec0 lzma qt3 zlib-devel libopenssl-devel libcurl-devel libxml2-devel libxslt-devel rubygem-sqlite3 sqlite3-devel rubygem-rake gcc-c++ bzip2 readline-devel zlib-devel libxml2-devel libxslt-devel libyaml-devel libopenssl-devel libffi45-devel
[ $? -eq 0 ] && echo SUCCESS
if [ $? -ne 0 ] 
then
	del_repo
	echo "If you have missing dependencies in your installation go to http://software.opensuse.org and add the necessary repositories."
	exit 1
fi
del_repo
echo "Installing ruby rvm tool ..."
set_proxy # only if behind a corporate firewall
bash < <( curl -L http://rvm.beginrescueend.com/releases/rvm-install-head )
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1
echo "Updating rvm..."
rvm get head ; rvm reload
[ $? -ne 0 ] && exit 1
echo "Installing ruby ..."
rvm install 1.9.2
[ $? -ne 0 ] && exit 1
rvm install 1.8.7
[ $? -ne 0 ] && exit 1
echo "Setting ruby 1.9.2 as default ..."
rvm --default use 1.9.2

GEM=/usr/local/rvm/rubies/`ls /usr/local/rvm/rubies/ | grep 1.9`/bin/gem

echo "Installing neccessary gems ..."
$GEM install bundler -v 1.0.10 --no-rdoc --no-ri
[ $? -ne 0 ] && exit 1
$GEM install vmc -v 0.3.10 --no-rdoc --no-ri
[ $? -ne 0 ] && exit 1
$GEM install rack -v 1.2.2 --no-rdoc --no-ri
[ $? -ne 0 ] && exit 1
$GEM install rake -v 0.8.7 --no-rdoc --no-ri
[ $? -ne 0 ] && exit 1
$GEM install thin -v 1.2.11 --no-rdoc --no-ri
[ $? -ne 0 ] && exit 1
$GEM install sinatra -v 1.2.1 --no-rdoc --no-ri
[ $? -ne 0 ] && exit 1
$GEM install eventmachine -v 0.12.10 --no-rdoc --no-ri
[ $? -ne 0 ] && exit 1
$GEM install nats -v 0.4.8 --no-rdoc --no-ri
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

echo "Creating directories ..."
mkdir -p /opt/cloudfoundry/
[ $? -ne 0 ] && exit 1
mkdir -p /var/vcap/sys/log
[ $? -ne 0 ] && exit 1
mkdir -p /var/vcap/shared
[ $? -ne 0 ] && exit 1
mkdir -p /var/vcap/services
[ $? -ne 0 ] && exit 1
chmod -R 777 /var/vcap
mkdir -p /var/vcap.local
chmod 777 /var/vcap.local
[ $? -eq 0 ] && echo SUCCESS
[ $? -ne 0 ] && exit 1

pushd /opt/cloudfoundry
echo "Downloading common archive ..."
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
popd

echo "All operations completed Successfully!"
echo "Source rvm config file ('source /etc/profile.d/rvm.sh') or logoff and login again before executing any next installation scripts!!!"