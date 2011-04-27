require 'spec_helper'

describe "A Spring application being staged" do
  before do
    app_fixture :spring_guestbook
  end

  it "is packaged with a startup script" do
    stage :spring do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      webapp_root = staged_dir.join('tomcat', 'webapps', 'ROOT')
      webapp_root.should be_directory
      webapp_root.join('WEB-INF', 'web.xml').should be_readable
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
export CATALINA_OPTS="-server -Xms512m -Xmx512m -XX:MaxPermSize=128m -Dfile.encoding=UTF-8 -Djava.awt.headless=true"
export CATALINA_OPTS="$CATALINA_OPTS `ruby resources/set_environment`"
env > env.log
PORT=-1
while getopts ":p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
  esac
done
if [ $PORT -lt 0 ] ; then
  echo "Missing or invalid port (-p)"
  exit 1
fi
ruby resources/generate_server_xml $PORT
cd tomcat
./bin/catalina.sh run > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
echo "#!/bin/bash" >> ../stop
echo "kill -9 $STARTED" >> ../stop
echo "kill -9 $PPID" >> ../stop
chmod 755 ../stop
wait $STARTED
      EXPECTED
    end
  end

  it "requests the specified amount of memory from the JVM" do
    environment = { :resources => {:memory => 256} }
    stage(:spring, environment) do |staged_dir|
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
export CATALINA_OPTS="-server -Xms256m -Xmx256m -XX:MaxPermSize=64m -Dfile.encoding=UTF-8 -Djava.awt.headless=true"
export CATALINA_OPTS="$CATALINA_OPTS `ruby resources/set_environment`"
env > env.log
PORT=-1
while getopts ":p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
  esac
done
if [ $PORT -lt 0 ] ; then
  echo "Missing or invalid port (-p)"
  exit 1
fi
ruby resources/generate_server_xml $PORT
cd tomcat
./bin/catalina.sh run > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
echo "#!/bin/bash" >> ../stop
echo "kill -9 $STARTED" >> ../stop
echo "kill -9 $PPID" >> ../stop
chmod 755 ../stop
wait $STARTED
      EXPECTED
    end
  end
end

