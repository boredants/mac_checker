# mac_checker
MAC Address OUI Checker
Dump the MAC Address Table of a Cisco switch via snmp and check the OUIs against the IEEE database.
Generates a text file with count, OUI and manufacturer.
Also returns any unidentified OUIs which can be further investigated if necessary.

Requires the snmpbulkwalk utility.

With a slight mod, can easily work on a Linux machine.
