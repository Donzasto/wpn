#!/bin/bash
USER=
SERVER=
PORT=
ADDRESS1=
ADDRESS2=
DNSIP=
SSH_KEY=
# Server
ssh $USER@$SERVER -i $SSH_KEY << EOF 
apt update
apt install wireguard
apt-get install wireguard-dkms wireguard-tools linux-headers-\$(uname -r) 
mkdir ~/wireguard
cd ~/wireguard 
umask 077 
wg genkey | tee server_private_key | wg pubkey > server_public_key
wg genkey | tee client_private_key | wg pubkey > client_public_key
sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
echo -e "[Interface]
Address = $ADDRESS1
#PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o \`ip route show default | awk '{print \$5}'\` -j MASQUERADE
PostUp = nft add rule ip filter FORWARD iifname %i counter accept; nft add rule ip filter FORWARD oifname %i counter accept; nft add rule ip nat POSTROUTING oifname \`ip route show default | awk '{print \$5}'\` counter masquerade
#PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o \`ip route show default | awk '{print \$5}'\` -j MASQUERADE
PostDown = nft delete rule ip filter FORWARD iifname %i counter accept; nft delete rule ip filter FORWARD oifname %i counter accept; nft delete rule ip nat POSTROUTING oifname \`ip route show default | awk '{print \$5}'\` counter masquerade
ListenPort = $PORT 
PrivateKey = \$(cat server_private_key)

[Peer]
PublicKey = \$(cat client_public_key)
AllowedIPs = $ADDRESS2" > /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0.service
systemctl restart wg-quick@wg0.service
exit
EOF
# Client
sudo pacman -S wireguard-tools
sudo mkdir /etc/wireguard
echo -e "[Interface]
Address = $ADDRESS2
PrivateKey = $(ssh $USER@$SERVER -i $SSH_KEY 'cat ~/wireguard/client_private_key')
DNS = $DNSIP

[Peer]
PublicKey = $(ssh $USER@$SERVER -i $SSH_KEY 'cat ~/wireguard/server_public_key')
Endpoint = $SERVER:$PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" | sudo tee /etc/wireguard/wg0-client.conf
sudo pacman -S openresolv
sudo wg-quick up wg0-client
