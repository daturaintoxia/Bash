#!/bin/bash


# Uppdatera systemet

dnf update -y

dnf upgrade -y


# Installera nödvändiga verktyg och aktivera brandvägg

dnf install -y firewalld wget curl nano git

systemctl enable --now firewalld


# Öppna nödvändiga portar i brandväggen

firewall-cmd --permanent --add-port=9090/tcp   # Prometheus

firewall-cmd --permanent --add-port=9116/tcp   # SNMP Exporter

firewall-cmd --permanent --add-port=3000/tcp   # Grafana

firewall-cmd --reload


# Lägg till Prometheus repository och installera Prometheus
curl -s https://packagecloud.io/install/repositories/prometheus-rpm/release/script.rpm.sh | bash
dnf install -y prometheus

# Skapa användaren prometheus om den inte finns
useradd --no-create-home --shell /bin/false prometheus

# Skapa kataloger och sätt rätt rättigheter
mkdir -p /etc/prometheus /var/lib/prometheus
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Skapa Prometheus konfigurationsfil
cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['127.0.0.1:9090']
EOF

# Skapa systemd servicefil för Prometheus
cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --storage.tsdb.retention.time=30d

[Install]
WantedBy=multi-user.target
EOF

# Ladda om systemd och starta Prometheus
systemctl daemon-reload
systemctl enable --now prometheus

echo "Prometheus är installerad och igång på port 9090."


# Installera Grafana

dnf install -y https://dl.grafana.com/oss/release/grafana-10.2.3-1.x86_64.rpm

systemctl enable --now grafana-server


echo "Installation av Prometheus och Grafana är klar!" 