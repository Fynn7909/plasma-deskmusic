# Desk Music

Musik-Widget mit Glas-Look für den KDE-Plasma-6-Desktop. Steuert jeden Player, der MPRIS kann (Spotify, Firefox, Chrome, VLC, …).

*Frosted-glass music widget for the KDE Plasma 6 desktop. Controls any MPRIS player.*

## Funktionen

- Glas-Hintergrund: weichgezeichnetes Hintergrundbild, leicht getönt in der Farbe des Covers
- Cover, Titel, Interpret, Zeitleiste zum Spulen, Lautstärke des Players
- Animationen:
  - neues Cover schiebt sich beim Skippen in Skip-Richtung herein
  - Titel und Interpret gleiten mit
  - lange Titel laufen nach kurzer Pause durch, mit weich ausgeblendeten Rändern
  - Cover schrumpft bei Pause, Schatten wächst bei Play
  - Play/Pause-Symbol blendet über, Skip-Symbole schubsen in ihre Richtung
  - Balken werden beim Anfassen dicker
- Holt sich das Cover von einem anderen Player, wenn der aktive (z. B. Browser) keins liefert

## Voraussetzungen

- KDE Plasma 6
- Qt5Compat-Grafikeffekte
  - Fedora: `sudo dnf install qt6-qt5compat`
  - Arch: `sudo pacman -S qt6-5compat`
  - Debian/Ubuntu: `sudo apt install qml6-module-qt5compat-graphicaleffects`

## Installation

```bash
git clone https://github.com/Fynn7909/plasma-deskmusic.git
kpackagetool6 -t Plasma/Applet -i plasma-deskmusic
```

Dann Rechtsklick auf den Desktop, **Miniprogramme hinzufügen**, nach **Desktop-Musik** suchen und auf den Desktop ziehen.

Aktualisieren:

```bash
cd plasma-deskmusic && git pull
kpackagetool6 -t Plasma/Applet -u .
```

Falls das Widget danach noch alt aussieht: `systemctl --user restart plasma-plasmashell.service`

Entfernen:

```bash
kpackagetool6 -t Plasma/Applet -r org.franz.deskmusic
```

## Lizenz

GPL-2.0-or-later, siehe [LICENSE](LICENSE).
