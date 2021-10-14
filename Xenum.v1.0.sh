#!/bin/bash

# Updated by Rob Hughes

RED="\033[01;31m"
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
BLUE="\033[01;34m"
BOLD="\033[01;01m"
RESET="\033[00m"

source ./nseScans.sh
#-- check for root or exit
if [ $EUID != 0 ]
then
    echo -e "\n[${RED}!${RESET}] must be ${RED}root${RESET}"
    exit 1
fi

declare -a tools=("masscan" "cat" "dig" "curl" "nmap" "ike-scan" "nbtscan" "wfuzz")

# check all prerequisite tools are installed, or quit
for tool in ${tools[*]}
do
    #echo ${tool[*]}
    if ! which "$tool" > /dev/null
    then
	echo -e "\n[${RED}!${RESET}] $tool ${RED}not${RESET} found"
	echo -e "\n[${RED}!${RESET}] Ensure the following tools are installed: ${tools[*]}"
	exit 1
    fi
done
# populate files and folders
declare -a files=("./targets.ip" "./exclude.ip")
declare -a folders=("scans" "open-ports" "nse_scans" "masscan/scans/" "nmap/scans/")

for file in ${files[*]}
do
    if [ ! -f "$file" ]
    then
	touch $file
        echo -e "\n[${GREEN}+${RESET}] Populate the ${YELLOW} $file ${RESET} file"
	exit 1
    fi
done

for folder  in ${folders[*]}
do
    if [ ! -d "$folder" ]
    then
	mkdir -p $folder         
    fi
done

#-- Nmap variables
MINHOST=$1
if  [[ -z "$MINHOST" ]]; then
    MINHOST=50
fi

MINRATE=$2
if  [[ -z "$MINRATE" ]]; then
    MINRATE=500
fi

#-- port variables
PORTRANGE=$3
if  [[ -z "$PORTRANGE" ]]; then
    PORTRANGE=1-65535
fi
MINPORT=$(echo $PORTRANGE | cut -d '-' -f 1)
MAXPORT=$(echo $PORTRANGE | cut -d '-' -f 2)

# - masscan variables
adapter=$4
if  [[ -z "$adapter" ]]; then
    adapter=eth0
fi

#-- scan functions


massscanPortScan(){
    MAXRATE=
    if  [[ -z "$MAXRATE" ]]; then
	read -p "[!] Set Masscans value for --max-rate (500): " MAXRATE
    fi
    if [[ -z "$MAXRATE" ]];
    then
	MAXRATE=500
    fi
    echo -e "\n[+] ${BOLD}Masscan Starting"
    echo -e "\n[${GREEN}+${RESET}] Running a ${YELLOW}port scan${RESET} for all IPs in masscan/alive.ip"
    masscan --open -iL targets.ip \
	    --excludefile exclude.ip \
	    -oG masscan/scans/$PORTRANGE.gnmap -v \
	    -p $PORTRANGE \
            --adapter $adapter \
	    --max-rate=$MAXRATE
}

PortSort(){

cat masscan/scans/$PORTRANGE.gnmap | grep Host | awk '{ print $5 }' | awk -F/ '{ print $1 }' | grep [0-9] | sort -u | tr '\n' ',' > masscan/scans/portlist.txt

}

Findalive(){

cat masscan/scans/*.gnmap | head -n -1 | tail -n +3 | cut -d ' ' -f 2 | sort -u > masscan/alive.ip

}

nmapPortScan(){
    echo -e "\n[${GREEN}+${RESET}] Running an ${YELLOW}nmap port scan${RESET} for all ip in masscan/alive.ip"
    nmap --open -iL masscan/alive.ip \
	 -p `echo $(cat masscan/scans/portlist.txt)` -v -n -O -sV -sC --reason -Pn -oA nmap/scans/portscan \
	 --min-hostgroup $MINHOST --min-rate=$MINRATE
}

nmapUDP(){
   echo -e "\n[${GREEN}+${RESET}] Running an ${YELLOW}nmap UDP port scan${RESET} for all IP's"
   nmap --open -iL targets.ip \
   -sUV -vv -F -oA nmap/scans/udp_portscan \
   --version-intensity 0
}

#-- combining masscan and nmap results
combiner(){
    echo -e "\n[${GREEN}+${RESET}] Combining ${YELLOW}nmap${RESET} and ${YELLOW}masscan${RESET} scans"
    touch alive.ip
    touch nmap/alive.ip
    touch masscan/alive.ip
    cp masscan/scans/* scans
    cp nmap/scans/* scans
    cat masscan/scans/$PORTRANGE.gnmap | head -n -1 | tail -n +3 | cut -d ' ' -f 2 | sort -u > masscan/alive.ip
    cat nmap/scans/udp_portscan | head -n -1 | tail -n +3 | cut -d ' ' -f 2 | sort -u > nmap/alive.ip
    cat masscan/alive.ip nmap/alive.ip | sort -u >> alive.ip
}

#-- summary
summary(){
    echo -e "\n[${GREEN}+${RESET}] Generating a summary of the scans..."
    echo -e "\n[${GREEN}+${RESET}] there are $(cat masscan/alive.ip | wc -l ) ${YELLOW}alive hosts${RESET} and $(egrep -o '[0-9]*/open/' nmap/scans/*.gnmap | cut -d ':' -f 2 | sort | uniq | wc -l) ${YELLOW}unique ports/services${RESET}"
}

#-- summary with UDP results merged
summary2(){
    echo -e "\n[${GREEN}+${RESET}] Generating a summary of the scans..."
    echo -e "\n[${GREEN}+${RESET}] there are $(cat alive.ip | wc -l ) ${YELLOW}alive hosts${RESET} and $(egrep -o '[0-9]*/open/' nmap/scans/*.gnmap | cut -d ':' -f 2 | sort | uniq | wc -l) ${YELLOW}unique ports/services${RESET}"
}

menuChoice(){
    read -p "Choose an option: " choice
    case "$choice" in
	1 ) echo "[1] selected, running -- Masscan|Nmap|NSEs"
	    massscanPortScan
            PortSort
            Findalive
            nmapPortScan
            summary;;
	2 ) echo "[2] selected, running -- Masscan | Nmap | NSEs | UDP Scan!"
	    massscanPortScan
	    PortSort
            Findalive
	    nmapPortScan
            nmapUDP
            combiner
            summary2;;
    esac
}


#Start the script
if (( "$#" < 4 )); #If not provided the 4 arguments - show usage
then
    MINHOST=50
    MINRATE=500
    PORTRANGE=1-1024
    echo -e "[!] Not entered all 3 arguments - Setting default values as shown in the usage example below!"
    echo -e "Usage Example: sudo bash ./Xenum.sh 50 500 1-1024 eth0"
    echo -e "./Xenum.sh [Nmap min hostgroup] [Nmap min rate] [Port range] [adapter]\n"
    echo -e "[1] Continue Default TCP Scans (Masscan, Nmap and Nse's)? "
    echo -e "[2] Continue Default TCP Scans including Nmap Default UDP? "
    menuChoice
elif (( "$#" == 4 ));
then
    echo -e "
___   ___  _______ .__   __.  __    __  .___  ___. 
\  \ /  / |   ____||  \ |  | |  |  |  | |   \/   | 
 \  V  /  |  |__   |   \|  | |  |  |  | |  \  /  | 
  >   <   |   __|  |  . `  | |  |  |  | |  |\/|  | 
 /  .  \  |  |____ |  |\   | |  `--'  | |  |  |  | 
/__/ \__\ |_______||__| \__|  \______/  |__|  |__| 
                                                   
version 1.0                                                  
                            
"                       
    echo -e "The External Network Enumeration Tool - By Rob Hughes"
    echo -e ""    
    echo -e ""    
    echo -e "Arguments taken:"
    echo -e "--min-hostgroup: " $1
    echo -e "--min-rate: " $2
    echo -e "--port-range: " $3
    echo -e "[1] Continue Default TCP Scans (Masscan, Nmap and Nse's)? "
    echo -e "[2] Continue Default TCP Scans including Nmap Default UDP? "
    menuChoice 
fi
