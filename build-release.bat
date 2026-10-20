@echo off
set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco\sdk
set JAVA_HOME=C:\Program Files\Huawei\DevEco\jbr
set PATH=C:\Program Files\Huawei\DevEco\jbr\bin;%PATH%
rem NOTE: cd to the drive root first. Otherwise the session keeps a lowercase
rem drive letter (c:\...) and hvigor's path check (realpathSync.native(p) === p)
rem fails, reporting "Path not found. At file: c:\Users\Andy\mashen-app\entry".
cd /d C:\
cd /d C:\Users\Andy\caishen-app
node hvigorw.js --mode project -p product=release -p buildMode=release --no-daemon assembleApp
