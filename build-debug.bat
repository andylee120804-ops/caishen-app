@echo off
set DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco\sdk
set JAVA_HOME=C:\Program Files\Huawei\DevEco\jbr
set PATH=C:\Program Files\Huawei\DevEco\jbr\bin;%PATH%
rem NOTE: cd to the drive root first (see build-release.bat for the reason).
cd /d C:\
cd /d C:\Users\Andy\caishen-app
node hvigorw.js --mode module -p product=default -p buildMode=debug --no-daemon assembleHap
