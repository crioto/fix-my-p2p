#!/bin/bash

clear

os=`uname -s`
if which tput >/dev/null 2>&1; then
      ncolors=$(tput colors)
fi
if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    GRAY="$(tput setaf 7)"
    BOLD="$(tput bold)"
    NORMAL="$(tput sgr0)"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    GRAY=""
    BOLD=""
    NORMAL=""
fi

unrecoverable() 
{
    echo ""
    echo "${BOLD}Sorry!${NORMAL}"
    echo -e "This error is unrecoverable! We are done here!\n\n"
    exit 1
}

show_fail()
{
    echo -e "\r\t\t\t\t\t\t\t\t\t${RED}${BOLD}[FAIL]${NORMAL}"
}

show_ok()
{
    echo -e "\r\t\t\t\t\t\t\t\t\t${GREEN}${BOLD}[OK]${NORMAL}"
}

show_done()
{
    echo -e "\r\t\t\t\t\t\t\t\t\t${GREEN}${BOLD}[DONE]${NORMAL}"
}

check_p2p_path()
{
if [ "$p2p_path" != "" ]; then
    echo -ne "Checking if provided path is correct"
    $p2p_path -v > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        show_fail
        p2p_path=""
        echo "We will try to find p2p automatically"
    else
        show_ok
    fi
fi
}

find_p2p_command() 
{
read -r -d '' binary_locations << EOM
p2p
subutai.p2p
subutai-master.p2p
subutai-dev.p2p
subutai-sysnet.p2p
/opt/subutai/bin/p2p
/usr/local/bin/p2p
EOM

if [ "$p2p_path" == "" ]; then
    echo -ne "Determining p2p command"
    while read -r line; do
        $line -v > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            p2p_path=$line
            break
        fi
    done <<< "$binary_locations"

    if [ "$p2p_path" == "" ]; then
        show_fail
        echo -e "\n${YELLOW}${BOLD}You can specify path to p2p as a parameter to this script${NORMAL}\n"
        unrecoverable
    else
        show_ok
    fi
fi
}

detect_service_name()
{
read -r -d '' service_units << EOM
snap.subutai.p2p-service.service
snap.subutai-dev.p2p-service.service
snap.subutai-master.p2p-service.service
snap.subutai-sysnet.p2p-service.service
p2p.service
EOM
if [ "$os" == "Linux" ]; then
    echo -ne "Determining service name"
    while read -r line; do
        systemctl is-enabled $line > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            unit_name=$line
            break
        fi
    done <<< "$service_units"

    if [ "$unit_name" == "" ]; then
        show_fail
        echo -ne "Skipping logs"
        show_ok
    else
        show_ok
    fi
fi
}

echo -e "${BLUE} "
cat <<BANNER
===============================================================================
 _____  ____  __ __        ____  ______        ___ ___  ____  __  _    ___  __ 
|     |l    j|  T  T      l    j|      T      |   T   Tl    j|  l/ ]  /  _]|  T
|   __j |  T |  |  | _____ |  T |      |      | _   _ | |  T |  ' /  /  [_ |  |
|  l_   |  | l_   _j|     ||  | l_j  l_j      |  \_/  | |  | |    \ Y    _]|__j
|   _]  |  | |     |l_____j|  |   |  | __     |   |   | |  | |     Y|   [_  __ 
|  T    j  l |  |  |       j  l   |  |T  |    |   |   | j  l |  .  ||     T|  T
l__j   |____j|__j__|      |____j  l__jl_ |    l___j___j|____jl__j\_jl_____jl__j
                                        \l                                     
===============================================================================

Fix-It, Mike! Version 1.0

This script will collect information about Subutai P2P from your peer/host, pack
it and tell you how to get it. This process can take some time. This script is 
intend to be run on peer or on your host. 

Mike.

BANNER

echo -e "${NORMAL} "

date=`date +%Y-%m-%d-%H_%M_%S`
name="p2p-$os-$date"
output="/tmp/$name"
unit_name=""
p2p_path="$1"

$(sudo ls /) >/dev/null 2>&1

check_p2p_path
find_p2p_command
detect_service_name

echo -ne "Creating directory ${BOLD}$output${NORMAL}"
mkdir -p $output > /dev/null 2>&1
if [ $? != 0 ]; then 
    show_fail
    unrecoverable
else
    show_ok
fi

if [ "$unit_name" != "" ]; then
    if [ "$os" == "Linux" ]; then
        echo -ne "Executing ${BOLD}journalctl${NORMAL} and collecting logs"
        sudo journalctl -u $unit_name > $output/p2p.log 2>&1
    else
        echo -ne "Executing ${BOLD}cat /var/log/p2p.log${BOLD} to collect logs"
        cat /var/log/p2p.log > $output/p2p.log 2>&1
    fi

    if [ $? != 0 ]; then
        show_fail
    else
        show_ok
    fi
fi


echo -ne "Executing ${BOLD}p2p debug${NORMAL}"
p2p_debug=$($p2p_path debug)

if [ $? != 0 ]; then
    show_fail
else
    show_ok
fi

echo "$p2p_debug" > $output/p2p_debug.out

printf '%s\n' "$p2p_debug" | while IFS= read -r line
do
   clear_line=`echo "$line" | tr -d '\t'`
   if [ "${clear_line:0:3}" == "IP:" ]; then
    ip=${clear_line:3}
    echo -ne "Sending ping to $ip"
    ping $ip -c 10 > $output/ping-$ip-out 2>&1
    show_done
   fi
done

echo -ne "Collecting network information"
if [ "$os" == "Linux" ]; then
    ( ip addr > $output/ifconfig.out 2>&1 )
else
    ( ifconfig > $output/ifconfig.out 2>&1 )
fi
if [ $? != 0 ]; then
    show_fail
else
    show_ok
fi

echo -ne "Collecting p2p status"
$p2p_path status > $output/p2p_status.out 2>&1 
if [ $? != 0 ]; then
    show_fail
else
    show_ok
fi

echo -ne "Packaging into /tmp/$name.tar.gz"
cd /tmp
tar zcvf $name.tar.gz $output/* > /dev/null 2>&1
if [ $? != 0 ]; then
    show_fail
else
    show_ok
fi

rm -rf $output

echo -e "\n${YELLOW}${BOLD}Finished!${NORMAL}\n"
echo "We have created a file here: ${GREEN}${BOLD}/tmp/$name${NORMAL}.tar.gz"
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    echo "You need to move it to your computer and send it to mike"
    echo "For example, you can try to execute \`scp\` command on your host:"
    echo -e "\t${BOLD}scp <USER>@<HOST>:/tmp/$name.tar.gz ~${NORMAL}"
    echo "Replace <USER> with username on this computer"
    echo "Replace <HOST> with IP address of this computer"
    echo "If you did everything right you will see a file named"
    echo "${YELLOW}$name.tar.gz${NORMAL} in your home directory!"
fi
echo -e "\n${BOLD}~ Good Bye ~${NORMAL}\n"
