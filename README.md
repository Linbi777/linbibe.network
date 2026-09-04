# linbibe.network

Omarchy Wi-Fi panel with extra tabs for **Amnezia VPN** and **WireGuard**.
Both tunnels can stay up at the same time.

Clone of `omarchy.network`, with a Shibumi-style tab row on the Wi-Fi icon:

- **Wi-Fi** — stock network list, DNS, band
- **Amnezia** — start/stop the AmneziaVPN client
- **WireGuard** — NetworkManager WireGuard profiles (`nmcli`)

## Install

```bash
omarchy plugin add https://github.com/Linbi777/linbibe.network.git --enable
omarchy bar move linbibe.network --before omarchy.audio
```

If a stock `omarchy.network` widget is still on the bar, remove it so only this clone remains.

## Requirements

- Omarchy / `omarchy-shell`
- NetworkManager + `nmcli` for WireGuard
- AmneziaVPN app for the Amnezia tab (`AmneziaVPN --connect <index>`)

## Notes

Amnezia has no session CLI: connect restarts the GUI with `--connect`. Disconnect
SIGTERMs the client, then restores the host network (tun2, DNS, IPv6, killswitch)
so other VPNs and plain Wi-Fi keep working. It does **not** relaunch with
`--autostart`.
WireGuard uses existing NetworkManager profiles and does not tear Amnezia down.
