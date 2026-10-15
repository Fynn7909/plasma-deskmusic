import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Mpris.Mpris2Model { id: mpris }

    // Browser-Player liefern oft kein Cover: gleiches Lied bei anderem Player suchen
    Instantiator {
        id: players
        model: mpris
        delegate: QtObject { required property var container }
    }

    readonly property var player: mpris.currentPlayer
    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string track: hasPlayer && player.track ? player.track : "Keine Musik"
    readonly property string artist: hasPlayer ? (player.artist || player.identity) : "Starte Spotify o. Ä."
    readonly property string art: {
        if (!hasPlayer) return ""
        if (player.artUrl.toString()) return player.artUrl
        for (let i = 0; i < players.count; i++) {
            const c = players.objectAt(i)?.container
            if (c && c.track === player.track && c.artUrl.toString()) return c.artUrl
        }
        return ""
    }
    readonly property real progress: hasPlayer && player.length > 0 ? Math.min(1, player.position / player.length) : 0

    // Richtung des letzten Titelwechsels: 1 = vor, -1 = zurück, 0 = von außen
    property int direction: 0
    function skip(d) {
        direction = d
        directionReset.restart()
        if (d > 0) player.Next(); else player.Previous()
    }
    Timer { id: directionReset; interval: 2500; onTriggered: root.direction = 0 }

    // Farbe des Covers für eine leichte Tönung des Glases
    Image {
        id: tintSource
        visible: false
        source: root.art
        sourceSize: Qt.size(48, 48)
        asynchronous: true
        onStatusChanged: if (status === Image.Ready) albumColors.update()
    }
    Kirigami.ImageColors { id: albumColors; source: tintSource }
    readonly property color albumTint: tintSource.status === Image.Ready && root.art
        ? albumColors.dominant : Qt.rgba(0, 0, 0, 0)

    function fmt(us) {
        const s = Math.max(0, Math.floor(us / 1000000))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: track
    toolTipSubText: artist

    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: root.player.updatePosition()
    }

    readonly property string uiFont: {
        const families = Qt.fontFamilies()
        for (const name of ["SF Pro Display", "SF Pro Text", "Inter Variable", "Inter"]) {
            if (families.includes(name)) return name
        }
        return Kirigami.Theme.defaultFont.family
    }

    // Dünner weißer Balken ohne Griff, wird beim Anfassen dicker (Scrubber und Lautstärke)
    component GlassBar: Item {
        id: bar
        property real value: 0
        property real wheelStep: 0
        // Dauer, mit der die Füllung Wertänderungen von außen folgt
        property int settle: 250
        property int settleEasing: Easing.OutQuint
        property real dragValue: 0
        readonly property bool pressed: area.pressed
        readonly property bool active: area.pressed || area.containsMouse
        // nach dem Loslassen kurz den eigenen Wert halten, bis der Player nachgezogen hat
        readonly property real shown: area.pressed || hold.running ? dragValue : value
        signal changing(real v)
        signal committed(real v)

        function push(v) {
            dragValue = Math.max(0, Math.min(1, v))
            hold.restart()
            changing(dragValue)
        }

        implicitHeight: 14
        Timer { id: hold; interval: 600 }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: area.pressed ? 10 : area.containsMouse ? 8 : 4
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

            Rectangle {
                width: parent.width * bar.shown
                height: parent.height
                radius: parent.radius
                color: "white"
                opacity: bar.active ? 1 : 0.8
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on width {
                    enabled: !area.pressed
                    NumberAnimation { duration: bar.settle; easing.type: bar.settleEasing }
                }
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            hoverEnabled: true
            preventStealing: true
            onPressed: mouse => bar.push(mouse.x / bar.width)
            onPositionChanged: mouse => { if (pressed) bar.push(mouse.x / bar.width) }
            onReleased: bar.committed(bar.dragValue)
            onWheel: wheel => {
                if (bar.wheelStep <= 0) {
                    wheel.accepted = false
                    return
                }
                bar.push(bar.shown + (wheel.angleDelta.y > 0 ? bar.wheelStep : -bar.wheelStep))
                bar.committed(bar.dragValue)
            }
        }
    }

    // Weißes Symbol, reagiert schon beim Drücken
    component GlyphButton: Item {
        id: button
        property string icon
        property real size: 20
        // >0 / <0: Symbol schiebt sich beim Klick kurz in diese Richtung
        property int nudge: 0
        readonly property bool hovered: tap.containsMouse
        property string shownIcon: icon
        signal clicked()

        onIconChanged: {
            ghost.source = shownIcon
            shownIcon = icon
            swap.restart()
        }

        implicitWidth: size + 14
        implicitHeight: size + 14
        opacity: enabled ? 1 : 0.35
        scale: tap.pressed ? 0.86 : 1
        Behavior on scale { NumberAnimation { duration: tap.pressed ? 90 : 320; easing.type: Easing.OutQuint } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
            opacity: tap.pressed ? 0.2 : tap.containsMouse ? 0.1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        Item {
            anchors.fill: parent
            transform: Translate { id: shove }

            // altes Symbol schrumpft weg, neues wächst an derselben Stelle
            Kirigami.Icon {
                id: ghost
                anchors.centerIn: parent
                width: button.size
                height: button.size
                isMask: true
                color: "white"
                opacity: 0
            }
            Kirigami.Icon {
                id: glyph
                anchors.centerIn: parent
                width: button.size
                height: button.size
                source: button.shownIcon
                isMask: true
                color: "white"
            }
        }
        ParallelAnimation {
            id: swap
            NumberAnimation { target: ghost; property: "scale"; from: 1; to: 0.4; duration: 200; easing.type: Easing.OutQuint }
            NumberAnimation { target: ghost; property: "opacity"; from: 1; to: 0; duration: 160 }
            NumberAnimation { target: glyph; property: "scale"; from: 0.4; to: 1; duration: 340; easing.type: Easing.OutQuint }
            NumberAnimation { target: glyph; property: "opacity"; from: 0; to: 1; duration: 220 }
        }
        SequentialAnimation {
            id: nudgeAnim
            NumberAnimation { target: shove; property: "x"; to: button.nudge * 5; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: shove; property: "x"; to: 0; duration: 420; easing.type: Easing.OutQuint }
        }
        MouseArea {
            id: tap
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (button.nudge !== 0) nudgeAnim.restart()
                button.clicked()
            }
        }
    }

    // Zu langer Text läuft nach kurzer Pause durch, Ränder blenden weich aus
    component MarqueeLabel: Item {
        id: marquee
        property string text
        property alias font: first.font
        property color color: "white"
        readonly property real gap: 36
        readonly property bool overflow: first.implicitWidth > width + 1

        implicitHeight: first.implicitHeight
        clip: true
        onTextChanged: { run.stop(); strip.x = 0; if (overflow) run.restart() }
        onOverflowChanged: { strip.x = 0; if (overflow) run.restart(); else run.stop() }

        Item {
            id: content
            anchors.fill: parent
            visible: !marquee.overflow
            Row {
                id: strip
                spacing: marquee.gap
                Text { id: first; text: marquee.text; color: marquee.color; renderType: Text.NativeRendering }
                Text { text: marquee.text; font: first.font; color: marquee.color; visible: marquee.overflow; renderType: Text.NativeRendering }
            }
        }
        // linker Rand blendet nur aus, während der Text läuft
        readonly property real leftFade: strip.x < 0 ? 14 : 0
        Rectangle {
            id: fadeMask
            anchors.fill: parent
            visible: false
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: marquee.leftFade > 0 ? "transparent" : "white" }
                GradientStop { position: 14 / Math.max(1, marquee.width); color: "white" }
                GradientStop { position: 1 - 18 / Math.max(1, marquee.width); color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        GE.OpacityMask {
            anchors.fill: parent
            visible: marquee.overflow
            source: content
            maskSource: fadeMask
        }
        SequentialAnimation {
            id: run
            loops: Animation.Infinite
            PauseAnimation { duration: 3000 }
            NumberAnimation {
                target: strip
                property: "x"
                from: 0
                to: -(first.implicitWidth + marquee.gap)
                duration: (first.implicitWidth + marquee.gap) / 32 * 1000
            }
        }
    }

    fullRepresentation: Item {
        id: full
        readonly property real corner: 22
        readonly property real pad: 14

        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 5
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        Layout.preferredHeight: Kirigami.Units.gridUnit * 7

        // Hintergrundbild hinter dem Widget, weichgezeichnet statt abgedunkelt
        Item {
            id: glass
            property Item wallpaper: null
            property point origin: Qt.point(0, 0)

            function locate() {
                for (let p = parent; p; p = p.parent) {
                    if (p.wallpaper) {
                        wallpaper = p.wallpaper
                        origin = mapToItem(p.wallpaper, 0, 0)
                        return
                    }
                }
            }

            anchors.fill: parent
            Component.onCompleted: locate()
            onWidthChanged: locate()
            onHeightChanged: locate()
            Timer {
                interval: 2000
                running: true
                repeat: true
                onTriggered: glass.locate()
            }

            ShaderEffectSource {
                id: behind
                anchors.fill: parent
                visible: false
                sourceItem: glass.wallpaper
                sourceRect: Qt.rect(glass.origin.x, glass.origin.y, glass.width, glass.height)
            }
            Rectangle {
                id: rounded
                anchors.fill: parent
                radius: full.corner
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                visible: glass.wallpaper !== null
                source: behind
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 0.75
                blurMax: 64
                saturation: 0.35
                maskEnabled: true
                maskSource: rounded
            }
            // Farbschimmer aus dem Cover, blendet beim Titelwechsel langsam über
            Rectangle {
                anchors.fill: parent
                radius: full.corner
                color: Qt.rgba(root.albumTint.r, root.albumTint.g, root.albumTint.b, root.albumTint.a * 0.28)
                Behavior on color { ColorAnimation { duration: 900; easing.type: Easing.OutCubic } }
            }
            // Material: leichte Tönung für Lesbarkeit, helle Haarlinie als Lichtkante
            Rectangle {
                anchors.fill: parent
                radius: full.corner
                color: Qt.rgba(0.07, 0.07, 0.08, glass.wallpaper ? 0.3 : 0.7)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: full.pad
            spacing: full.pad

            // Cover, schrumpft bei Pause; beim Titelwechsel schiebt sich das neue
            // Cover in Skip-Richtung herein, das alte gleitet zur anderen Seite raus
            Item {
                id: coverBox
                Layout.fillHeight: true
                Layout.preferredWidth: height
                scale: root.playing ? 1 : 0.88
                Behavior on scale { NumberAnimation { duration: 550; easing.type: Easing.OutQuint } }

                property int front: 0
                property bool pending: false
                function slot(i) { return slots.itemAt(i) }

                function load(url) {
                    const back = slot(1 - front)
                    if (!back) return
                    pending = true
                    back.source = url
                    if (back.settled) reveal()
                }
                function reveal() {
                    if (!pending) return
                    pending = false
                    const incoming = slot(1 - front)
                    const outgoing = slot(front)
                    front = 1 - front
                    const shift = width * 0.22 * root.direction
                    incoming.z = 1
                    outgoing.z = 0
                    flip.stop()
                    inX.target = incoming; inX.from = shift
                    inScale.target = incoming; inScale.from = root.direction ? 0.9 : 0.96
                    inFade.target = incoming; inFade.from = 0
                    outX.target = outgoing; outX.to = -shift
                    outScale.target = outgoing; outScale.to = root.direction ? 0.9 : 1
                    outFade.target = outgoing
                    flip.start()
                }

                Connections {
                    target: root
                    function onArtChanged() { coverBox.load(root.art) }
                }

                ParallelAnimation {
                    id: flip
                    NumberAnimation { id: inX; property: "x"; to: 0; duration: 520; easing.type: Easing.OutQuint }
                    NumberAnimation { id: inScale; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutQuint }
                    NumberAnimation { id: inFade; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                    NumberAnimation { id: outX; property: "x"; duration: 360; easing.type: Easing.OutQuint }
                    NumberAnimation { id: outScale; property: "scale"; duration: 360; easing.type: Easing.OutQuint }
                    NumberAnimation { id: outFade; property: "opacity"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                }

                Repeater {
                    id: slots
                    model: 2
                    delegate: Item {
                        id: slotItem
                        required property int index
                        property alias source: img.source
                        // geladen oder endgültig ohne Bild
                        readonly property bool settled: !img.source.toString() || img.status === Image.Ready || img.status === Image.Error
                        width: coverBox.width
                        height: coverBox.height
                        Component.onCompleted: {
                            if (index === 0) img.source = root.art
                            else opacity = 0
                        }
                        onSettledChanged: if (settled && coverBox.slot(1 - coverBox.front) === slotItem) coverBox.reveal()

                        Kirigami.ShadowedImage {
                            id: img
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            radius: full.corner - full.pad
                            asynchronous: true
                            visible: status === Image.Ready
                            shadow.size: root.playing ? 18 : 8
                            shadow.yOffset: root.playing ? 6 : 3
                            shadow.color: Qt.rgba(0, 0, 0, root.playing ? 0.4 : 0.25)
                            Behavior on shadow.size { NumberAnimation { duration: 550; easing.type: Easing.OutQuint } }
                            Behavior on shadow.yOffset { NumberAnimation { duration: 550; easing.type: Easing.OutQuint } }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: img.radius
                            color: Qt.rgba(1, 1, 1, 0.1)
                            visible: img.status !== Image.Ready
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: parent.width * 0.45
                                height: width
                                source: "media-default-album-symbolic"
                                isMask: true
                                color: "white"
                                opacity: 0.6
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: full.pad

                    // Titel und Interpret: alter Text gleitet raus, neuer kommt aus Skip-Richtung
                    ColumnLayout {
                        id: meta
                        Layout.fillWidth: true
                        spacing: 1
                        property string shownTrack: root.track
                        property string shownArtist: root.artist
                        transform: Translate { id: metaShift }

                        function swap() { metaSwap.restart() }
                        Connections {
                            target: root
                            function onTrackChanged() { meta.swap() }
                            function onArtistChanged() { meta.swap() }
                        }
                        SequentialAnimation {
                            id: metaSwap
                            ParallelAnimation {
                                NumberAnimation { target: meta; property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
                                NumberAnimation { target: metaShift; property: "x"; to: -10 * root.direction; duration: 120; easing.type: Easing.InCubic }
                            }
                            ScriptAction {
                                script: {
                                    meta.shownTrack = root.track
                                    meta.shownArtist = root.artist
                                    metaShift.x = 12 * root.direction
                                }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: meta; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
                                NumberAnimation { target: metaShift; property: "x"; to: 0; duration: 480; easing.type: Easing.OutQuint }
                            }
                        }

                        MarqueeLabel {
                            Layout.fillWidth: true
                            text: meta.shownTrack
                            font.family: root.uiFont
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.2
                        }
                        MarqueeLabel {
                            Layout.fillWidth: true
                            text: meta.shownArtist
                            opacity: 0.6
                            font.family: root.uiFont
                            font.pixelSize: 13
                        }
                    }

                    // Lautstärke des Players selbst (MPRIS), nicht die Systemlautstärke
                    RowLayout {
                        id: volume
                        property real lastAudible: 0.5
                        readonly property real value: volumeBar.shown

                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        visible: root.hasPlayer && root.player.canControl

                        GlyphButton {
                            size: 16
                            implicitWidth: 24
                            implicitHeight: 24
                            opacity: volumeBar.active || hovered ? 1 : 0.7
                            icon: volume.value <= 0 ? "audio-volume-muted-symbolic"
                                : volume.value < 0.34 ? "audio-volume-low-symbolic"
                                : volume.value < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"
                            onClicked: {
                                if (volume.value > 0) {
                                    volume.lastAudible = volume.value
                                    volumeBar.push(0)
                                } else {
                                    volumeBar.push(volume.lastAudible)
                                }
                            }
                        }
                        GlassBar {
                            id: volumeBar
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5.5
                            value: root.hasPlayer ? Math.max(0, Math.min(1, root.player.volume)) : 0
                            wheelStep: 0.05
                            onChanging: v => root.player.volume = v
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                GlassBar {
                    id: scrubber
                    Layout.fillWidth: true
                    visible: root.hasPlayer && root.player.length > 0
                    enabled: root.hasPlayer && root.player.canSeek
                    value: root.progress
                    // läuft zwischen den Sekundentakten gleichmäßig weiter
                    settle: 1000
                    settleEasing: Easing.Linear
                    onCommitted: v => root.player.position = root.player.length * v
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PC3.Label {
                        text: root.hasPlayer && root.player.length > 0 ? root.fmt(root.player.length * scrubber.shown) : ""
                        color: "white"
                        opacity: scrubber.pressed ? 0.95 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        font.family: root.uiFont
                        font.pixelSize: 11
                        font.features: { "tnum": 1 }
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                    }
                    Item { Layout.fillWidth: true }
                    GlyphButton {
                        icon: "media-skip-backward-symbolic"
                        nudge: -1
                        enabled: root.hasPlayer && root.player.canGoPrevious
                        onClicked: root.skip(-1)
                    }
                    GlyphButton {
                        icon: root.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                        size: 26
                        enabled: root.hasPlayer && (root.player.canPlay || root.player.canPause)
                        onClicked: root.player.PlayPause()
                    }
                    GlyphButton {
                        icon: "media-skip-forward-symbolic"
                        nudge: 1
                        enabled: root.hasPlayer && root.player.canGoNext
                        onClicked: root.skip(1)
                    }
                    Item { Layout.fillWidth: true }
                    PC3.Label {
                        text: root.hasPlayer && root.player.length > 0 ? "-" + root.fmt(root.player.length * (1 - scrubber.shown)) : ""
                        color: "white"
                        opacity: scrubber.pressed ? 0.95 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        font.family: root.uiFont
                        font.pixelSize: 11
                        font.features: { "tnum": 1 }
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                    }
                }
            }
        }
    }
}
