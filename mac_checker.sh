#!/bin/bash

echo -e "\n#####################################################################"
echo "# MAC CHECKER:  COMPILE A LIST OF MAC ADDRESS OUIs FROM A DEVICE ON #"
echo "# YOUR NETWORK AND CHECK IT AGAINST THE IEEE DATABASE.  OUTLIERS    #"
echo "# SHOULD BE INVESTIGATED                                            #"
echo -e "#####################################################################\n"

#Check that the script isn't being run as root
if [ ${UID} = 0 ]
	then
		echo "${0}: This script should not be run as root.  Exiting..."
		logger "${0}: This script should not be run as root.  Exiting..."
		exit 100
fi

MIB=".1.3.6.1.2.1.3.1.1.2"
IEEE_URL="http://standards-oui.ieee.org/oui/oui.txt"
OUI_FILE="oui.txt"
OUI_NORM="oui_normalized.txt"
DEVICE_MACS="mac_table.txt"
TEMP_FILE="temp.txt"
RESULTS_FILE="results.txt"

#Download or update (if more than 30 days old) the list of OUI's and then normalize it
if [ ! -s ${OUI_FILE} ]
	then
		echo -e "Downloading ${OUI_FILE}...\n"
		wget ${IEEE_URL} -O ${OUI_FILE}
		tail -n +5 ${OUI_FILE} | awk -F '\t' '{print $1 $3}' | grep -Ev '^[a-zA-Z0-9]{2}-' |\
                grep -v '^$' | sed 's/(base 16)//' | sed 's///g' | grep -v '^$' > ${OUI_NORM}
		logger "${0}: Downloading OUIs from ${IEEE_URL}"
	else
		if [ $(find ${OUI_FILE} -type f -mtime +30) ]
			then
				echo -e "The ${OUI_FILE} file is over 30 days old.  Updating...\n"
				rm -f ${OUI_FILE}
				rm -f ${OUI_NORM}
				wget ${IEEE_URL} -O ${OUI_FILE}
				tail -n +5 ${OUI_FILE} | awk -F '\t' '{print $1 $3}' | grep -Ev '^[a-zA-Z0-9]{2}-' |\
				grep -v '^$' | sed 's/(base 16)//' | sed 's///g' | grep -v '^$' > ${OUI_NORM}
				logger "${0}: Updating OUIs from ${IEEE_URL}"
		fi
fi


#Get a list of MAC addresses (normalized down to the OUI) to check
#The default is a Cisco switch
#snmpbulkwalk is needed - Ex: apt install -y snmp

#As another example, this command should work for a Linux machine, just edit or comment out the next 10 or so
#lines of code accordingly:
#arp | cut -d ' ' -f 6 | grep -v '^$' | sed 's/://g' | cut -c 1-6 | tr [a-z] [A-Z]

echo -e "\nWe will now use snmp to gather the MAC address table from a Cisco switch:"
echo -e "Enter the snmp version (2, 2c, 3): "
read snmpVersion
echo -e "\nEnter the community string: "
read commString
echo -e  "\nEnter the IP address of the device: "
read ipAddress

echo -e  "\nGathering MAC Addresses..."
snmpbulkwalk -v $snmpVersion -c $commString -OXsq $ipAddress $MIB | cut -d '"' -f 2 | sed 's/ //g' | cut -c 1-6 > ${DEVICE_MACS}

if [ -s ${DEVICE_MACS} ]
	then
		logger "${0}: Gathering MAC Addresses from ${ipAddress} " 
		echo -e "\nFinished... Now identifying the OUI's..."
		while read line
			do
				grep $line ${OUI_NORM} 2>/dev/null >> ${TEMP_FILE}

			done<${DEVICE_MACS}

		cat ${TEMP_FILE} | sort | uniq -c | sort -nr >> ${RESULTS_FILE}
		rm -f ${TEMP_FILE}

		while read line
			do
				if ! grep -q $line ${OUI_NORM} 2>/dev/null
					then
						echo "$line     NOT FOUND" >> ${TEMP_FILE}
				fi
			done<${DEVICE_MACS}
			
		echo -e "\n#####################################################" >> ${RESULTS_FILE}
		echo -e "##THE FOLLOWING OUIs WERE NOT ABLE TO BE IDENTIFIED##" >> ${RESULTS_FILE} 
		echo -e "#####################################################\n" >> ${RESULTS_FILE}

		#cat ${TEMP_FILE} | sort | grep ^[0-9A-F] | uniq -c | grep [^0-9][^A-Z] | sort -nr >> ${RESULTS_FILE}
		cat ${TEMP_FILE} | sort | grep ^[0-9A-F] | uniq -c | sort -nr >> ${RESULTS_FILE}
		rm -f ${TEMP_FILE}

		echo -e "\nFinished... Results have been written to '${RESULTS_FILE}'.  Exiting...\n"
		logger "${0}: Script finished successfully"
		exit

	else
		echo -e "\nYour attempt to gather MAC addresses failed or yielded no results.  Exiting...\n"
		logger "${0}: Script did not finish successfully"
		exit 200
fi
