#!/bin/bash

set -e

echo "[INFO] Configurando Ubuntu como router..."

# Check if we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Este script debe ejecutarse como root (sudo ./ubuntu_router.sh)"
    exit 1
fi

# Check if sudo is installed, if not install it
if ! command -v sudo &> /dev/null; then
    echo "[INFO] sudo no está instalado. Instalando..."
    apt update
    apt install -y sudo
fi

# Habilitar IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Instalar dependencias necesarias
apt update
apt install -y vlan net-tools iproute2 ifupdown iptables-persistent ufw

# Cargar módulo 8021q para VLAN
modprobe 8021q
echo "8021q" >> /etc/modules

# Configurar interfaces VLAN (ajusta eth0 si tu interfaz es diferente)
IFACE=eth0
cat > /etc/network/interfaces.d/vlans.cfg <<EOF
auto ${IFACE}
iface ${IFACE} inet manual

auto ${IFACE}.10
iface ${IFACE}.10 inet static
    address 192.168.10.1
    netmask 255.255.255.0
    vlan-raw-device ${IFACE}

auto ${IFACE}.20
iface ${IFACE}.20 inet static
    address 192.168.20.1
    netmask 255.255.255.0
    vlan-raw-device ${IFACE}

auto ${IFACE}.30
iface ${IFACE}.30 inet static
    address 192.168.30.1
    netmask 255.255.255.0
    vlan-raw-device ${IFACE}

auto ${IFACE}.99
iface ${IFACE}.99 inet static
    address 192.168.99.1
    netmask 255.255.255.0
    vlan-raw-device ${IFACE}
EOF

echo "[INFO] Interfaces VLAN configuradas."

# Reinciar networking
ifdown $IFACE || true
ifup $IFACE
ifup ${IFACE}.10 || true
ifup ${IFACE}.20 || true
ifup ${IFACE}.30 || true
ifup ${IFACE}.99 || true

echo "[INFO] Interfaces VLAN levantadas."

# Configurar NAT para salida a Internet (asumiendo que la interfaz WAN es ens33, cambia si es distinto)
WAN_IFACE=ens33
iptables -t nat -A POSTROUTING -o $WAN_IFACE -j MASQUERADE

# Permitir tráfico entre interfaces y salida a Internet
iptables -A FORWARD -i $WAN_IFACE -o $IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $IFACE -o $WAN_IFACE -j ACCEPT

# Guardar reglas de iptables
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

echo "[INFO] Reglas de iptables aplicadas y guardadas."

# Configurar UFW
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Permitir tráfico entre VLANs y acceso a servicios comunes
ufw allow in on ${IFACE}.10
ufw allow in on ${IFACE}.20
ufw allow in on ${IFACE}.30
ufw allow in on ${IFACE}.99
ufw allow ssh
ufw allow 53    # DNS
ufw allow 80    # HTTP
ufw allow 443   # HTTPS

ufw --force enable

echo "[INFO] UFW configurado y habilitado."

echo "[✅] Ubuntu Router configurado exitosamente con VLANs, iptables y UFW."
