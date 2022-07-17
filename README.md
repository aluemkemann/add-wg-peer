# add-wg-peer
Simple shell script to generate WireGuard peer configurations and QR codes

Script to generate and Wireguard peer (client) configs. Tested on Ubiquiti Dream Machine Pro (Busybox / Debian based Router), Debian and its flavors, Windows 10 and 11 (using WSL 2.0, Windows Services for Linux).

The script has very few dependencies: a running wireguard instance, bash, curl. If you want to generate QR codes the package qrencode - which should also be pretty standard on many distros.

# Description
It works by reading the information from your running wireguard instance through the wg utility. Writing back to wireguard is done by the wg-quick utility because wg can't handle some config values. To generate a unique IP address for each client the wireguard instance needs to be running so we can read the already assigned client IPs, sort them and find the next free IP.

# Usage #
Copy the script to your wireguard server and run it like this:
bash add_wg_peer.sh --peername MyClient  --interface wg0 --serverconf --clientconf --qrcode --verbose
You will be asked if you want to add the newly generated client to your running instance, and if yes, if you want to save the changes to the wireguard config file.

usage: add_wg_peer [options]
-V | --verbose	  		Output various default settings

-Q | --qrcode		    	Print client QR code to screen

-S | --serverconf		  Generate a peer stub file to append to server config

-C | --clientconf	  	Write Wireguard client configuration to file

-i | --interface		  Specify the Wireguard interface to work on (Default: wg0)

-s | --server			    Server IP or DNS Name (Default: looked up external IP Address of this machine)

-n | --peername			  Friendly name of the peer, is used to generate the config files name (Default: PeerName)

-d | --peerdns			  The DNS the peer uses when the tunnel is established (Default: 9.9.9.9)

-m | --mtu				    The clients MTU size (Default:1420)

-f | --peerconfigfile	Optional, if set overrides the output file name

-I | --interactive	  Activate interactive mode

-h | --help			    	This help text

