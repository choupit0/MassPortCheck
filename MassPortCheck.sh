#!/bin/bash

##################################################################################################################################
#
# Script Name    : MassPortCheck.sh
# Description    : This script launching scanning process in parallel to only find open TCP ports.
#                  This is useful with TOR Network. There is no complex scanning process as Nmap or Masscan.
#                  It simply uses netcat tool.
# Author         : https://github.com/choupit0
# Site           : https://hack2know.how/
# Date           : 20200319
# Version        : 1.0
# Usage          : ./MassPortCheck.sh [IP address or hostname] [first port range] [last port range] [number of parallels process]
#		   e.g. (proxychains) ./MassPortCheck.sh 192.168.2.1 1 65535 50 
# Prerequisites  : netcat
#
##################################################################################################################################

version="1.0"
yellow_color="\033[1;33m"
green_color="\033[0;32m"
red_color="\033[1;31m"
blue_color="\033[0;36m"
bold_color="\033[1m"
end_color="\033[0m"
script_start="$SECONDS"
date="$(date +%F_%H-%M-%S)"
host="$1"
port1="$2"
port2="$3"
nb_proc="$4"

# Time elapsed
time_elapsed(){
script_end="$SECONDS"
script_duration="$((script_end-script_start))"

printf 'Duration: %02dh:%02dm:%02ds\n' $((${script_duration}/3600)) $((${script_duration}%3600/60)) $((${script_duration}%60))
}

# Check if hostname or IP address is valid 
if [[ ! -z "${host}" ]] && [[ ! $(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "${host}" > /dev/null 2>&1) ]]; then
	if [[ ! $(host "${host}" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}') ]]; then
		echo -e "${red_color}[X] Host \"${host}\" not valid (DNS or typo issue).${end_color}"
		exit 1
	fi
fi

usage(){
echo -e "${blue_color}${bold_color}Usage: ${end_color} ./$(basename "$0") ${bold_color}[IP address or hostname] [first port range] [last port range] [number of parallels process to launch]${end_color}"
echo -e "${bold_color} -> e.g. (proxychains) ./$(basename "$0") ${bold_color}www.acme.org 1 65535 50${end_color}"
}

# Valid input parameters?
checking_parameters(){
parameter="$1"

if [[ -z ${parameter} ]] || [[ ! ${parameter} = +([0-9]) ]]; then
        echo -e "${red_color}[X] Input parameter(s) does not present or is not a positive integer.${end_color}"
	usage
        exit 1
fi
}

checking_parameters "${port1}"
checking_parameters "${port2}"
checking_parameters "${nb_proc}"

# Cleaning
rm process_done.txt input_file.txt 2>/dev/null

# Testing Internet access
internet_testing="$(nc -z -v -w 1 google.com 443 > /dev/null 2>&1 && nc -z -v -w 1 youtube.com 443 > /dev/null 2>&1)"

if [ $? -gt 0 ]; then
        echo -e "${red_color}[X] No Internet access: firewall? TOR issue?...${end_color}"
        echo -e "${yellow_color}[I] If you are using TOR network, launch again the script. ${end_color}"
        echo -e "${yellow_color}[I] If it's happen again, reload your tor connection: systemctl reload tor${end_color}"
	exit 1
else
        echo -e "${yellow_color}[I] Internet access is working.${end_color}"

fi

# File construction
for port in $(seq "${port1}" "${port2}"); do 
        echo "${host} ${port}" >> input_file.txt
done

echo -e "${yellow_color}${bold_color}\r[I] Work file is ready.${end_color}"

# Number of ports
nb_ports="$(grep -Ec "+([0-9])$" input_file.txt)"

# Function for parallel scans
parallels_scans(){
port="$(echo "$1" | cut -d" " -f2)"
result="$(nc -z -v -w 1 "$host" "$port" > /dev/null 2>&1)"

if [ $? -gt 0 ]; then
	echo "${host} ${port} (down) : Done" >> process_done.txt
else
	echo "${host} ${port} (open) : Done" >> process_done.txt
fi

#echo "${host} ${port} : Done" >> process_done.txt

proc_ended="$(grep "Done" -co process_done.txt)"
pourcentage="$(awk "BEGIN {printf \"%.2f\n\", ""${proc_ended}"/"${nb_ports}"*100"}")"
echo -n -e "\r                                                                                                         "
echo -n -e "${yellow_color}${bold_color}\r[I] Scan is done for port ${port} -> ${proc_ended}/${nb_ports} Scan process launched...(${pourcentage}%)${end_color}"
}

echo -e "${blue_color}${bold_color}[-] ${nb_ports} ports to scan for host \"${host}\" (${port1}-${port2}), ${nb_proc} process(es) launched in parallel(s)...${end_color}"

# Queue files
new_job(){
job_act="$(jobs | wc -l)"
while ((job_act >= "${nb_proc}")); do
	job_act="$(jobs | wc -l)"
done
parallels_scans "${ip_to_scan}" &
}

# We are launching the scans
count="1"

rm -rf process_done.txt

while IFS=, read -r ip_to_scan; do
	new_job
	count="$(expr $count + 1)"
done < input_file.txt

wait

sleep 1 && tset

echo -e "${green_color}[V] Scan phase is ended.${end_color}"

# Open ports
nb_open_ports="$(grep -c "open" process_done.txt)"
open_ports="$(grep "open" process_done.txt)"

echo -e "${bold_color}${nb_open_ports} open port(s).${end_color}"
grep -e "open" process_done.txt
grep -e "open" process_done.txt | cut -d":" -f1 > "${host}"_ports_"${date}".txt

echo -e "${bold_color}Your log file: ${host}_ports_${date}.txt ${end_color}"

rm process_done.txt input_file.txt 2>/dev/null

time_elapsed

exit 0
