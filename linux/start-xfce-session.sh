#!/usr/bin/env bash
# Uruchamia sesje XFCE podlaczona do zewnetrznego X Serwera na Windows (VcXsrv).
# Wywolywany automatycznie przez Start-Ubuntu-XFCE.ps1 - nie trzeba go uruchamiac recznie.
set -uo pipefail

DISPLAY_NUM="${XFCE_DISPLAY_NUM:-0}"
LOG="${HOME}/.xfce-session.log"

exec >>"$LOG" 2>&1
echo "===== start $(date) ====="

detect_host_ip() {
  local ip=""

  # 1) Domyslna trasa - najbardziej wiarygodne dla WSL2 (adres wirtualnego hosta Windows).
  ip="$(ip route show default 2>/dev/null | awk '{print $3; exit}')"

  # 2) Fallback: nameserver z /etc/resolv.conf, o ile nie jest to lokalny stub systemd-resolved.
  if [[ -z "$ip" ]]; then
    ip="$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)"
    if [[ "$ip" == "127.0.0.53" || "$ip" == "127.0.0.1" ]]; then
      ip=""
    fi
  fi

  # 3) Fallback: pierwszy adres hosta z /etc/hosts wpisany przez WSL (host.docker.internal-like).
  if [[ -z "$ip" ]] && command -v getent >/dev/null 2>&1; then
    ip="$(getent hosts host.docker.internal 2>/dev/null | awk '{print $1; exit}')"
  fi

  echo "$ip"
}

wait_for_port() {
  local host="$1" port="$2" tries=20
  while (( tries-- > 0 )); do
    if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then
      exec 3>&- 3<&-
      return 0
    fi
    sleep 0.5
  done
  return 1
}

HOST_IP="$(detect_host_ip)"
if [[ -z "$HOST_IP" ]]; then
  echo "BLAD: nie udalo sie wykryc adresu IP hosta Windows (sprawdz 'ip route' i /etc/resolv.conf)."
  exit 1
fi

XPORT=$((6000 + DISPLAY_NUM))
echo "Host Windows wykryty jako: $HOST_IP (port X: $XPORT)"

if ! wait_for_port "$HOST_IP" "$XPORT"; then
  echo "BLAD: serwer X (VcXsrv) nie odpowiada na ${HOST_IP}:${XPORT}."
  echo "      Sprawdz czy VcXsrv jest uruchomiony i czy Zapora Windows dopuszcza polaczenia z WSL."
  exit 2
fi

export DISPLAY="${HOST_IP}:${DISPLAY_NUM}"
export LIBGL_ALWAYS_INDIRECT=1
export NO_AT_BRIDGE=1
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE

# WSLg ustawia WAYLAND_DISPLAY globalnie w kazdej sesji WSL. Aplikacje GTK wykrywajac ten
# socket domyslnie wola Waylanda (WSLg) nad X11 NIEZALEZNIE od DISPLAY - efekt: panel,
# pulpit i inne komponenty XFCE laduja jako osobne natywne okna WSLg, a nie w oknie VcXsrv.
# Wylaczamy Wayland i wymuszamy X11 dla GTK/Qt, zanim wystartuje jakikolwiek klient X.
unset WAYLAND_DISPLAY
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export CLUTTER_BACKEND=x11

if [[ -S /mnt/wslg/PulseServer ]]; then
  export PULSE_SERVER=unix:/mnt/wslg/PulseServer
  echo "WSLg PulseAudio wykryty - dzwiek wlaczony przez $PULSE_SERVER"
fi

echo "DISPLAY=$DISPLAY, GDK_BACKEND=$GDK_BACKEND, WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-<brak>}"

if command -v autocutsel >/dev/null 2>&1; then
  autocutsel -fork
  autocutsel -selection PRIMARY -fork
fi

echo "Startuje XFCE..."

# Uruchamiamy dbus-launch w dwoch krokach (nie przez 'exec ... startxfce4' od razu), aby
# zdazyc zaktualizowac srodowisko aktywacji D-Bus/systemd - usluzki startowane przez
# aktywacje D-Bus (np. xfconfd, gvfsd) inaczej moglyby wciaz widziec WAYLAND_DISPLAY
# z chwili startu VM i same probowac uzyc Waylanda.
eval "$(dbus-launch --sh-syntax --exit-with-session)"
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    DISPLAY WAYLAND_DISPLAY GDK_BACKEND QT_QPA_PLATFORM CLUTTER_BACKEND XDG_SESSION_TYPE XDG_CURRENT_DESKTOP \
    2>/dev/null || true
fi

exec startxfce4
