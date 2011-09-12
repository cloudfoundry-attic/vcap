Instruction on how to enable remote debugging on Java application:

1. Setup Java app for remote debugging with Cloud Foundry

1) Deploy your Java web application as normal vmc push process
2) Stop the application running "vmc stop [appname]"
3) Run "vmc env-add [appname] JPDA=1". This will enable debugging for the Java application
4) You have choice to set the port number for debugging by running
       vmc env-add [appname] JPDA_ADDRESS=8080
5) Restart the application by running "vmc start [appname]". You are ready to debug your application.

2. Clean-up after remote debugging

You need to remove the environment variables that you set for remote debugging.

1)    Run "vmc env [appname]" to lookup all environment variables that you set
2)    Stop your app by running "vmc stop [appname]"
3)    Remove JPDA variable by "vmc env-del [appname] JPDA"
4)    Remove JPDA_ADDRESS by running "vmc env-del [appname] JPDA_ADDRESS"
5)    Restart your application by running "vmc start [appname]".

