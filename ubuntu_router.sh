#!/bin/bash

set -e

# Configuración básica
LAN_IFACE="ens224"
WAN_IFACE="ens192"

echo "[INFO] Habilitando IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/^#*net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf

echo "[INFO] Instalando paquetes necesarios..."
apt update && apt install -y vlan net-tools iproute2 ifupdown iptables-persistent ufw dos2unix

echo "[INFO] Cargando módulo 8021q para VLANs..."
modprobe 8021q
echo "8021q" >> /etc/modules

echo "[INFO] Configurando interfaces VLAN..."
mkdir -p /etc/network/interfaces.d

cat > /etc/network/interfaces.d/vlans.cfg <<EOF
auto $LAN_IFACE
iface $LAN_IFACE inet manual

auto $LAN_IFACE.10
iface $LAN_IFACE.10 inet static
    address 192.168.10.1
    netmask 255.255.255.0
    vlan-raw-device $LAN_IFACE

auto $LAN_IFACE.20
iface $LAN_IFACE.20 inet static
    address 192.168.20.1
    netmask 255.255.255.0
    vlan-raw-device $LAN_IFACE

auto $LAN_IFACE.30
iface $LAN_IFACE.30 inet static
    address 192.168.30.1
    netmask 255.255.255.0
    vlan-raw-device $LAN_IFACE

auto $LAN_IFACE.99
iface $LAN_IFACE.99 inet static
    address 192.168.99.1
    netmask 255.255.255.0
    vlan-raw-device $LAN_IFACE
EOF

echo "[INFO] Levantando interfaces..."
ifdown $LAN_IFACE || true
ifup $LAN_IFACE
ifup $LAN_IFACE.10
ifup $LAN_IFACE.20
ifup $LAN_IFACE.30
ifup $LAN_IFACE.99

echo "[INFO] Configurando NAT con iptables..."
iptables -t nat -A POSTROUTING -o $WAN_IFACE -j MASQUERADE
iptables -A FORWARD -i $WAN_IFACE -o $LAN_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $LAN_IFACE -o $WAN_IFACE -j ACCEPT
iptables-save > /etc/iptables/rules.v4

echo "[INFO] Configurando firewall con ufw..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 53
ufw allow 80
ufw allow 443
ufw allow in on $LAN_IFACE.10
ufw allow in on $LAN_IFACE.20
ufw allow in on $LAN_IFACE.30
ufw allow in on $LAN_IFACE.99
ufw enable

# (Opcional) Eliminar carpeta de repositorio si se desea
# echo "[INFO] Eliminando repositorio..."
# rm -rf /ruta/a/mi-repo

echo "[✅ COMPLETADO] Ubuntu configurado como router con VLANs, iptables y ufw."
