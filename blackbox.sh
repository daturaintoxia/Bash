#!/bin/bash

# ========================
# Inställningar
# ========================
PROM_CONFIG="/etc/prometheus/prometheus.yml"
BLACKBOX_IP="127.0.0.1"

# ========================
# Kontroll: root
# ========================
if [ "$EUID" -ne 0 ]; then
  echo "❌ Kör detta script som root (sudo)."
  exit 1
fi

# ========================
# Installera Blackbox Exporter
# ========================
echo "🔧 Installerar Blackbox Exporter..."
dnf install -y blackbox_exporter

# ========================
# Starta & aktivera tjänsten
# ========================
echo "🟢 Startar blackbox_exporter-tjänsten..."
systemctl enable --now blackbox_exporter

# ========================
# Öppna port i brandvägg
# ========================
echo "🌐 Öppnar brandväggsport 9115/tcp..."
firewall-cmd --add-port=9115/tcp --permanent
firewall-cmd --reload

# ========================
# Lägg till konfiguration i prometheus.yml
# ========================
echo "📝 Uppdaterar Prometheus-konfiguration..."

# Kontrollera om jobben redan finns
if grep -q "job_name: 'blackbox_http'" "$PROM_CONFIG"; then
  echo "⚠️ Konfiguration för 'blackbox_http' finns redan – hoppar över tillägg."
else
  cat <<EOF >> "$PROM_CONFIG"

  - job_name: 'blackbox_http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - http://192.168.205.13:9090
          - https://google.com
          - http://example.com:8080
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: ${BLACKBOX_IP}:9115

  - job_name: 'blackbox_icmp'
    metrics_path: /probe
    params:
      module: [icmp]
    static_configs:
      - targets:
          - 8.8.8.8
          - 192.168.1.1
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: ${BLACKBOX_IP}:9115
EOF

  echo "✅ Konfiguration tillagd i $PROM_CONFIG."
fi

# ========================
# Starta om Prometheus
# ========================
echo "🔁 Startar om Prometheus..."
systemctl restart prometheus

# ========================
# Klart
# ========================
echo "✅ Allt klart! Besök http://localhost:9090/targets för att verifiera Blackbox-jobben."
