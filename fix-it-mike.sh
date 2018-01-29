
clear

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
intend to be run on peer or on your host. Currently only Linux is fully
supported.

${BOLD}Highly recommended to run this script as root!${NORMAL}

Mike.

BANNER

echo -e "${NORMAL} "

date=`date +%Y-%m-%d-%H_%M_%S`
name="fix-it-mike-$date"
output="/tmp/$name"
echo -ne "Creating directory ${BOLD}$output${NORMAL}"

mkdir -p $output > /dev/null 2>&1
if [ $? != 0 ]; then 
    show_fail
    unrecoverable
else
    show_ok
fi

echo -ne "Executing ${BOLD}journalctl${NORMAL} and collecting logs"
journalctl > $output/p2p.log 2>&1

if [ $? != 0 ]; then
    show_fail
else
    show_ok
fi

echo -ne "Determining p2p path"
p2p_path=`which p2p`
if [ $? -ne 0 ]; then
    p2p_path=`which subutai.p2p`
    if [ $? -ne 0 ]; then
        p2p_path=`which subutai-master.p2p`
        if [ $? -ne 0 ]; then
            p2p_path=`which subutai-dev.p2p`
            if [ $? -ne 0 ]; then
                show_fail
                unrecoverable
            fi
        fi
    fi
fi
show_ok

echo -ne "Execute ${BOLD}p2p debug${NORMAL}"
p2p_debug=$(p2p debug)

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
    echo "Sending ping to $ip"
    ping $ip -c 10 > $output/ping-$ip-out 2>&1
    show_done
   fi
done

echo -ne "Collecting network information"
( ip addr > $output/ifconfig.out 2>&1 )
if [ $? != 0 ]; then
    show_fail
else
    show_ok
fi

echo -ne "Collecting p2p status"
p2p status > $output/status.out 2>&1 
if [ $? != 0 ]; then
    show_fail
else
    show_ok
fi

echo -ne "Packaging into /tmp/$name.tar.gz"
tar zcvf /tmp/$name.tar.gz $output/* > /dev/null 2>&1
if [ $? != 0 ]; then
    show_fail
else
    show_ok
fi

rm -rf $output

echo -e "\n${YELLOW}${BOLD}Finished!${NORMAL}\n"
echo "We have created a file here: ${GREEN}${BOLD}/tmp/$name${NORMAL}"
echo "You need to move it to your computer and send it to mike"
echo "For example, you can try to execute \`scp\` command on your host:"
echo -e "\t${BOLD}scp <USER>@<HOST>:/tmp/$name.tar.gz ~${NORMAL}"
echo "Replace <USER> with username on this computer"
echo "Replace <HOST> with IP address of this computer"
echo "If you did everything right you will see a file named"
echo "${YELLOW}$name.tar.gz${NORMAL} in your home directory!"
echo -e "\n${BOLD}~ Good Bye ~${NORMAL}\n"