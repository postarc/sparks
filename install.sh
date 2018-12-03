#!/bin/bash

CONFIG_FILE='sparks.conf'
CONFIGFOLDER='.sparkscore'
if [[ "$USER" == "root" ]]; then
        HOME_FOLDER="/root/"
		SCRIPT_FOLDER="/root/sparks"
 else
        HOME_FOLDER="/home/$USER/"
		SCRIPT_FOLDER="/home/$USER/sparks"
fi
COIN_PATH='/usr/local/bin/'
COIN_DAEMON='sparksd'
COIN_CLI='sparks-cli'
COIN_BIN_PATH='sparkscore-0.12.3/bin/'
SENTINEL_REPO='https://github.com/SparksReborn/sentinel.git'
COIN_TGZ='https://github.com/SparksReborn/sparkspay/releases/download/v0.12.3.2/sparkscore-0.12.3.2-linux64.tar.gz'
COIN_ZIP='sparkscore-0.12.3.2-linux64.tar.gz'
COIN_NAME='sparks'
COIN_PORT=8890
RPC_PORT=8818
PORT=$COIN_PORT


while [ -n "$(sudo lsof -i -s TCP:LISTEN -P -n | grep $RPC_PORT)" ]
do
(( RPC_PORT--))
done
echo -e "\e[32mFree RPCPORT address:$RPC_PORT\e[0m"
while [ -n "$(sudo lsof -i -s TCP:LISTEN -P -n | grep $PORT)" ]
do
(( PORT++))
done
echo -e "\e[32mFree MN port address:$PORT\e[0m"

NODEIP=$(curl -s4 icanhazip.com)


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function download_node() {
  echo -e "Download $COIN_NAME"
  cd
  wget -q $COIN_TGZ
  tar xvzf $COIN_ZIP
  rm $COIN_ZIP
  chmod +x $COIN_BIN_PATH$COIN_DAEMON $COIN_BIN_PATH$COIN_CLI
  #clear
}

function install_sentinel() {
  cd $CONFIGFOLDER
  echo -e "${GREEN}Installing sentinel.${NC}"
  apt-get -y install python-virtualenv virtualenv >/dev/null 2>&1
  git clone $SENTINEL_REPO $CONFIGFOLDER/sentinel >/dev/null 2>&1
  cd $CONFIGFOLDER/sentinel
  virtualenv ./venv >/dev/null 2>&1
  ./venv/bin/pip install -r requirements.txt >/dev/null 2>&1
  crontab -l > $CONFIGFOLDER$COIN_NAME.cron
  echo  "* * * * * cd $HOME_FOLDER$CONFIGFOLDER/sentinel && ./venv/bin/python bin/sentinel.py >> $CONFIGFOLDER/sentinel.log 2>&1" >> $CONFIGFOLDER$COIN_NAME.cron
  crontab $CONFIGFOLDER$COIN_NAME.cron
  rm $CONFIGFOLDER$COIN_NAME.cron >/dev/null 2>&1
  cd
}

function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
EOF
}

function create_key() {
  echo -e "${YELLOW}Enter your ${RED}$COIN_NAME Masternode GEN Key${NC}."
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then
  $COIN_PATH$COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the GEN Key${NC}"
    sleep 30
    COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  fi
  $COIN_PATH$COIN_CLI stop
fi
clear
}

function update_config() {
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE

masternode=1
externalip=$NODEIP
#bind=$NODEIP
maxconnections=256
masternodeaddr=$NODEIP:$COIN_PORT
port=$PORT
masternodeprivkey=$COINKEY
EOF
}


function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}



function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${GREEN}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
   echo -e "${GREEN}$0 must be run without sudo.${NC}"
   exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] && [ -d "$HOME_FOLDER$CONFIGFOLDER" ] ; then
  echo -e "${GREEN}$COIN_NAME is already installed.${NC}"
  exit 1
fi
}

function prepare_system() {
echo -e "Installing ${RED}$COIN_NAME${NC} Masternode."
sudo apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
sudo apt install -y software-properties-common >/dev/null 2>&1
sudo apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ libzmq5 unzip>/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pkg-config libevent-dev libzmq5"
 exit 1
fi

#clear
}

function ifp_autorun() {
#setup cron
crontab -l > tempcron
echo -e "@reboot $COIN_PATH$COIN_DAEMON -daemon" >> tempcron
echo -e "*/1 * * * * $SCRIPT_FOLDER/makerun.sh" >> tempcron
echo -e "*/30 * * * * $SCRIPT_FOLDER/checkdaemon.sh" >> tempcron
 crontab tempcron
rm tempcron
}

function ifp_start() {
sleep 2
if [ -f "$COIN_PATH$COIN_DAEMON" ]; then
	echo -e "${GREEN}Bin files exist, skipping copy.${NC}"
else
	sudo chown -R root:users $COIN_PATH
	sudo bash -c "cp $COIN_BIN_PATH$COIN_CLI $COIN_PATH"
	sudo bash -c "cp $COIN_BIN_PATH$COIN_DAEMON $COIN_PATH"
fi	
}

function important_information() {
 echo
 echo -e "=====================NODE====================="
 echo -e "$COIN_NAME Masternode is up and running listening on port ${GREEN}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${GREEN}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "VPS_IP:PORT ${GREEN}$NODEIP:$COIN_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${GREEN}$COINKEY${NC}"
 echo -e "=====================NODE====================="
 echo -e "Start node: $COIN_DAEMON -daemon"
 echo -e "Stop node: $COIN_CLI stop"
 echo -e "Block sync status: $COIN_CLI getinfo"
 echo -e "Node sync status: $COIN_CLI mnsync status"
 echo -e "Masternode status: $COIN_CLI masternode status"
}

function setup_node() {
  ifp_start
  get_ip
  create_config
  create_key
  update_config
  ifp_autorun
  important_information
  sudo ufw allow $PORT/tcp
  $COIN_DAEMON -reindex  
}

##### Main #####
#clear
checks
prepare_system
download_node
setup_node
install_sentinel
rm -rf sparkscore* 
