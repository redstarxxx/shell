#!/bin/bash

user_name=steam
log=/var/log/steam/pal_world_server.log

if [ ! -e "/var/log/steam/pal_server.log" ]; then
    sudo mkdir -p "$(dirname "$log")"
    sudo touch /var/log/steam/pal_server.log
fi

start_time=$SECONDS
echo "Start time: $(date +%F_%H:%M:%S)"

# https://developer.valvesoftware.com/wiki/SteamCMD#Windows

echo "Start detecting your os platform"
platform=$(. /etc/os-release && echo "$ID")
platform_version=$(. /etc/os-release && echo "$VERSION_ID")

echo "Your os: $platform $platform_version"

if [ "$platform" != "ubuntu" ] && [ "$platform" != "debian" ]; then
    echo "Your operating system is not supported by the current script"
    echo "Please refer to https://developer.valvesoftware.com/wiki/SteamCMD#Windows"
    exit 1
elif [ "$platform" == "debian" ] && [ "$platform_version" == "12" ]; then
    echo "Your operating system is not supported by the current script"
    echo "Please refer to https://developer.valvesoftware.com/wiki/SteamCMD#Windows"
    exit 1
fi
     
echo "start installing SteamCMD......"

if [ "$platform" == "ubuntu" ]; then
    sudo add-apt-repository multiverse -y > $log
    sudo dpkg --add-architecture i386 >> $log 
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y >> $log
    sudo DEBIAN_FRONTEND=noninteractive apt-get remove needrestart -y >> $log
    # 自动化接受EULA/许可协议, 参考https://qa.1r1g.com/askubuntu/ask/78572651/
    echo "auto agree EULA Agreement" >> $log
    echo steam steam/license note '' | sudo debconf-set-selections 
    echo steam steam/question select "I AGREE" | sudo debconf-set-selections 
    sudo DEBIAN_FRONTEND=noninteractive apt-get install steamcmd -y >> $log
else
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y > $log 
    sudo DEBIAN_FRONTEND=noninteractive apt-get install software-properties-common -y >> $log 
    sudo apt-add-repository non-free -y >> $log 
    sudo dpkg --add-architecture i386 >> $log  
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y >> $log
    echo steam steam/license note '' | sudo debconf-set-selections 
    echo steam steam/question select "I AGREE" | sudo debconf-set-selections   
    sudo DEBIAN_FRONTEND=noninteractive apt-get install steamcmd -y >> $log
    echo "export PATH=/usr/games:$PATH" >> ~/.bashrc
    source ~/.bashrc
fi 

# 检查steamcmd是否安装成功
command -v steamcmd > /dev/null 2>&1
if [ $? != 0 ]; then 
    echo "SteamCMD installation failed, Please try again"
    exit 1;
else 
    echo "SteamCMD installation successed."
fi

if id "$user_name" >/dev/null 2>&1; then
    echo "User: $user_name exists in your os"
else
    echo "Start creating new user named $user_name"
    # 新建用户并没有设置密码
    sudo useradd -m -s /bin/bash "$user_name"
fi

user_path=/home/steam

steamcmd_exec_path=$(which steamcmd)
sudo -u $user_name mkdir -p "$user_path"/.steam/sdk64/ >> $log
echo "Start downloading the dedicated server."
sudo -u $user_name "$steamcmd_exec_path" +login anonymous +app_update 2394010 validate +quit 2>&1 | tee -a $log
sudo -u $user_name "$steamcmd_exec_path" +login anonymous +app_update 1007 validate +quit 2>&1 | tee -a $log
sudo cp "$user_path"/Steam/steamapps/common/Steamworks\ SDK\ Redist/linux64/steamclient.so "$user_path"/.steam/sdk64/

echo "Write the service to boot self-startup"

cat <<EOF > /usr/lib/systemd/system/pal-world-server.service
[Unit]
Description=pal-world-server.service

[Service]
Type=simple
User=$user_name
Restart=on-failure
RestartSec=40s
ExecStart="$user_path"/Steam/steamapps/common/PalServer/PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable pal-world-server

echo "Starting palServer..."
sudo systemctl daemon-reload
sudo systemctl start pal-world-server.service

if systemctl --quiet is-active pal-world-server
then
    echo  "PalServer is running successfully!"
else
    echo  "Start PalServer failed, please check the log: $log."
    exit 1
fi
end_time=$SECONDS
echo "End time: $(date +%F_%H:%M:%S)"
execution_time=$((end_time - start_time))
hours=$((execution_time / 3600))
minutes=$(( (execution_time % 3600) / 60 ))
seconds=$((execution_time % 60))

formatted_time=$(printf "%02d h:%02d m:%02d s" $hours $minutes $seconds)
echo "exec time: $formatted_time" 2>&1 | tee -a $log
