#!/usr/bin/env bash
# One-time setup: installs XFCE and all supporting packages inside Ubuntu (WSL2).
# Run once with: bash setup-xfce.sh
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Nie uruchamiaj tego skryptu jako root / przez sudo. Uzyj zwyklego konta uzytkownika." >&2
  exit 1
fi

echo "==> Aktualizacja listy pakietow..."
sudo apt-get update -y

echo "==> Instalacja XFCE i zaleznosci..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  xfce4 \
  xfce4-goodies \
  dbus-x11 \
  x11-xserver-utils \
  xfonts-base \
  thunar \
  xfce4-terminal \
  autocutsel \
  pulseaudio-utils \
  fonts-noto \
  fonts-dejavu \
  dconf-cli

echo "==> Usuwanie ewentualnego menedzera logowania (niepotrzebny, startujemy XFCE recznie)..."
for dm in lightdm gdm3 sddm; do
  if dpkg -s "$dm" >/dev/null 2>&1; then
    sudo systemctl disable "$dm" >/dev/null 2>&1 || true
  fi
done

echo "==> Instalacja skryptu startowego sesji XFCE do ~/.local/bin ..."
mkdir -p "$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -m 755 "$SCRIPT_DIR/start-xfce-session.sh" "$HOME/.local/bin/start-xfce-session.sh"

echo "==> Konfiguracja XFCE (bez trybu uspienia/wygaszacza, ktore nie maja sensu w WSL)..."
mkdir -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
cat > "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
  </property>
</channel>
EOF

echo ""
echo "==> Gotowe. XFCE jest zainstalowane."
echo "    Sesje uruchamiaj z Windows za pomoca Start-Ubuntu-XFCE.ps1 (nie z tego okna)."
