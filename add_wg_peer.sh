#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function red {
	printf "${RED}$@${NC}\n"
}

function green {
	printf "${GREEN}$@${NC}\n"
}

function yellow {
	printf "${YELLOW}$@${NC}\n"
}

USAGE()
{
	echo "usage: add_wg_peer [options]
		-V | --verbose			Output various default settings
		-Q | --qrcode			Print client QR code to screen
		-S | --serverconf		Generate a peer stub file to append to server config
		-C | --clientconf		Write Wireguard client configuration to file
		-i | --interface		Specify the Wireguard interface to work on (Default: wg0)
		-s | --server			Server IP or DNS Name (Default: looked up external IP Address of this machine)
		-n | --peername			Friendly name of the peer, is used to generate the config files name (Default: PeerName)
		-d | --peerdns			The DNS the peer uses when the tunnel is established (Default: 9.9.9.9)
		-m | --mtu				The clients MTU size (Default:1420)
		-f | --peerconfigfile	Optional, if set overrides the output file name
		-I | --interactive		Activate interactive mode
		-h | --help				This help text"
}

SHOW_WGSERVER_INTERFACES()
{
		   WGSERVER_INTERFACES=$(wg show interfaces)
		   [[ -z "$WGSERVER_INTERFACES" ]] && { echo $(red "No Wireguard interfaces found! Aborting") ; exit 1 ; }
		   [[ -n "$WGSERVER_INTERFACES" ]] && { echo $(green "Following Wireguard interfaces found:") $(yellow "$WGSERVER_INTERFACES") ; }
}

CREATE_WG_KEYS()
{
		PRIVATE_KEY=$(wg genkey)
		PUBLIC_KEY=$(echo ${PRIVATE_KEY} | wg pubkey)
		PRESHARED_KEY=$(wg genpsk)
}

GET_WGSERVER_SETTINGS()
{
		WGSERVER_PORT=$(wg show $WGSERVER_INTERFACE listen-port)
		WGSERVER_PUBLIC_KEY=$(wg show $WGSERVER_INTERFACE public-key)
		WGSERVER_ADDRESS=$(curl -s ifconfig.me)
}

GET_WGPEERIP()
{
# Get next free peer IP (This will break after x.x.x.255)
WGPEER_ADDRESS=$(wg show ${WGSERVER_INTERFACE} allowed-ips | cut -f 2 | awk -F'[./]' '{print $1"."$2"."$3"."1+$4"/"$5}' | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -n | tail -n1)
}

CREATE_CONFIG_PEER()
{
cat <<- _EOF_
[Interface]
# Name = ${WGPEER_NAME}
Address = ${WGPEER_ADDRESS}
PrivateKey = ${PRIVATE_KEY}
DNS = ${WGPEER_DNS}
MTU = ${WGPEER_MTU}

[Peer]
PublicKey = ${WGSERVER_PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
AllowedIPs = 0.0.0.0/0
Endpoint = ${WGSERVER_ADDRESS}:${WGSERVER_PORT}
_EOF_
}

CREATE_STUBCONFIG_PEER()
{
cat <<- _EOF_
[Peer]
PublicKey = ${PUBLIC_KEY}
AllowedIPs = ${WGPEER_ADDRESS}
_EOF_
}

CREATE_QR_PEER()
{
		qrencode -t utf8 -o -
}

OUTPUT()
{
if [ "$VERBOSE" = "1" ]; then
		SHOW_VERBOSE
fi
if [ "$QRCODE" = "1" ]; then
		echo "$PEERCONFIG" | CREATE_QR_PEER
fi
if [ "$CLIENTCONF" = "1" ]; then
		echo "Writing Client Config to file: $WGPEER_CONFIGFILE"
		echo "$PEERCONFIG"
		echo "$PEERCONFIG" > $WGPEER_CONFIGFILE
fi
if [ "$SERVERCONF" = "1" ]; then
		echo "Writing Peer Definition to file: $PEERSTUBCONFIGFILE"
		echo "$PEERSTUBCONFIG" > $PEERSTUBCONFIGFILE
		echo "$PEERSTUBCONFIG"
fi
}

USAGE()
{
	echo "usage: add_wg_peer [options]
		-n | --peername			Friendly name of the peer, is used to generate the config files name (Default: PeerName)
		-i | --interface		Specify the Wireguard server interface to work on (Default: wg0)
		-C | --clientconf		Write Wireguard client configuration to file
		-S | --serverconf		Write peer definition to file. Contains just a stub that can be appended to the server config.
		-Q | --qrcode			Print client QR code to screen
		-s | --server			Server IP or DNS Name (Default: looked up external IP Address of this machine)
		-d | --peerdns			The DNS the peer uses when the tunnel is established (Default: 9.9.9.9)
		-m | --mtu				The clients MTU size (Default:1420)
		-f | --peerconfigfile	Optional, if set overrides the output file name
		-k | --keepalive		Optional, Defaults to 25 seconds
		-I | --interactive		Activate interactive mode
		-v | --verbose			Output various default settings
		-h | --help				This help text"
}

SHOW_VERBOSE()
{
	echo
	echo Arguments Verbose Output:
	echo
	echo $(green "WGPEER_NAME=") $(yellow "$WGPEER_NAME")
	echo $(green "WGSERVER_INTERFACE=") $(yellow "$WGSERVER_INTERFACE")
	echo $(green "WGSERVER_ADDRESS=") $(yellow "$WGSERVER_ADDRESS")
	echo $(green "WGSERVER_PORT=") $(yellow "$WGSERVER_PORT")
	echo $(green "WGSERVER_PUBLIC_KEY=") $(yellow "$WGSERVER_PUBLIC_KEY")
	echo $(green "WGPEER_IP=") $(yellow "$WGPEER_IP")
	echo $(green "WGPEER_DNS=") $(yellow "$WGPEER_DNS")
	echo $(green "WGPEER_MTU=") $(yellow "$WGPEER_MTU")
	echo $(green "WGPEER_CONFIGFILE=") $(yellow "$WGPEER_CONFIGFILE")
	echo $(green "Peer PRIVATE_KEY=") $(yellow "$PRIVATE_KEY")
	echo $(green "Peer PUBLIC_KEY=") $(yellow "$PUBLIC_KEY")
	echo $(green "Peer PRESHARED_KEY=") $(yellow "$PRESHARED_KEY")
	SHOW_WGSERVER_INTERFACES
	echo
}

ENABLE_PEER()
{
	if [ -f $PEERSTUBCONFIGFILE ]; then
		echo $(green "Stub config file:") $(yellow "Stub-$WGPEER_CONFIGFILE") $(green "exists.")
		echo -n "Append to Wireguard interface $WGSERVER_INTERFACE (y/n) > "
		read response
		if [ "$response" != "y" ]; then
			echo "Exiting program."
			exit 1
		fi
		echo $(green "Adding peer") $(yellow "$WGPEER_NAME") $(green "to running server config")
		wg addconf $WGSERVER_INTERFACE $PEERSTUBCONFIGFILE
		echo -n "Save to Wireguard config file for Wireguard Interface $WGSERVER_INTERFACE (y/n) > "
		read response
		if [ "$response" != "y" ]; then
			echo "Exiting program."
			exit 1
		fi
		echo $(green "Saving peer") $(yellow "$WGPEER_NAME") $(green "to server config file")
		wg-quick save $WGSERVER_INTERFACE
	fi
}

##### Main
INTERACTIVE=
WGSERVER_INTERFACE=wg0
WGPEER_NAME=PeerName
WGPEER_IP=4.3.2.1
WGPEER_DNS=9.9.9.9
WGPEER_MTU=1420
WGSERVER_ADDRESS=127.0.0.1
WGSERVER_PORT=51820
WGSERVER_PUBLIC_KEY=123456789123456789
CREATE_WG_KEYS
GET_WGSERVER_SETTINGS
GET_WGPEERIP

while [ "$1" != "" ]; do
	case $1 in
		-V | --verbose )      	VERBOSE=1
								;;
		-Q | --qrcode )       	QRCODE=1
								;;
		-S | --serverconf )		SERVERCONF=1
								;;
		-C | --clientconf )		CLIENTCONF=1	
								;;
		-i | --interface )      shift
								WGSERVER_INTERFACE=$1
								;;
		-s | --server )			shift
								WGSERVER_ADDRESS=$1
								;;
		-n | --peername )		shift
								WGPEER_NAME=$1
								WGPEER_CONFIGFILE=$WGPEER_NAME.conf
								PEERSTUBCONFIGFILE=Stub-$WGPEER_CONFIGFILE
								;;
		-d | --peerdns )		shift
								WGPEER_DNS=$1
								;;
		-m | --mtu )			shift
								WGPEER_MTU=$1
								;;
		-f | --peerconfigfile )	shift
								WGPEER_CONFIGFILE=$1
								;;
		-I | --interactive )	INTERACTIVE=1
								;;
		-h | --help )			Show this help
								exit
								;;
		* )						USAGE
								exit 1
	esac
	shift
done

if [ "$INTERACTIVE" = "1" ]; then
	response=
	read -p "Enter name of the Peer configuration file [$WGPEER_CONFIGFILE] > " response
	if [ -n "$response" ]; then
		WGPEER_CONFIGFILE="$response"
	fi

	if [ -f $WGPEER_CONFIGFILE ]; then
		echo -n "Output file "$WGPEER_CONFIGFILE" exists. Overwrite? (y/n) > "
		read response
		if [ "$response" != "y" ]; then
			echo "Exiting program."
			exit 1
		fi
	fi
fi
	
#SHOW_WGSERVER_INTERFACES
PEERCONFIG=$(CREATE_CONFIG_PEER)
PEERSTUBCONFIG=$(CREATE_STUBCONFIG_PEER)
OUTPUT
ENABLE_PEER
