import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Steam games you actually play, one click from the bar.
//
// The bar slot is a Steam mark; clicking it drops a popup of the most
// recently played installed games, newest first, each with the cover art
// Steam has already cached locally. Clicking a game launches it and closes
// the panel — the panel is a launcher, not a place to linger.
//
// Right-clicking the bar mark skips the list and opens the Steam library,
// which is what you want when the game you're after is not a recent one.
Panel {
  id: root
  moduleName: "io.github.unr3leas3d.steam-recent"
  ipcTarget: "io.github.unr3leas3d.steam-recent"

  // ---- Settings (shell.json, under this widget's bar entry)
  readonly property int gameCount: Math.max(1, Math.min(12, Number(setting("count", 5)) || 5))
  readonly property bool showCovers: setting("covers", true) !== false

  property var games: []
  property bool loaded: false
  // -1 means "no keyboard cursor yet", so the first arrow press selects the
  // top row rather than moving off an invisible selection.
  property int cursor: -1
  // Sampled rather than live: "17d ago" only changes at midnight, and a
  // binding on a clock would repaint every row every tick for nothing.
  property real now: Date.now()

  readonly property string scriptPath:
    Qt.resolvedUrl("scripts/steam-recent").toString().replace(/^file:\/\//, "")

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function refresh() {
    now = Date.now()
    if (!listProc.running) listProc.running = true
  }

  // Refresh on the way open, so a game played since the shell started is
  // already in the list by the time the panel paints.
  function open() {
    refresh()
    controller.show()
  }

  function launch(row) {
    if (!row || !bar) return
    bar.run("uwsm-app -- steam steam://rungameid/" + row.appid)
    close()
  }

  function openLibrary() {
    if (bar) bar.run("uwsm-app -- steam steam://open/games")
    close()
  }

  function moveCursor(delta) {
    cursor = Model.moveCursor(cursor, delta, games.length)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (!opened) cursor = -1

  Process {
    id: listProc
    command: [root.scriptPath, String(root.gameCount)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.games = Model.parseRows(text)
        root.loaded = true
        root.cursor = -1
      }
    }
  }

  // Steam only flushes playtime when it exits, so nothing changes minute to
  // minute. This is here to catch a game quit while the panel sits open.
  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: root.opened ? "" : "Steam"

    onPressed: function(b) {
      if (b === Qt.RightButton) root.openLibrary()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) { root.moveCursor(dy !== 0 ? dy : dx) }
      onActivateRequested: if (root.cursor >= 0) root.launch(root.games[root.cursor])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

        // ---------- Header: section label · refresh ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(header.implicitHeight, refreshButton.implicitHeight)

          PanelSectionHeader {
            id: header
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Recently played"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          PanelActionButton {
            id: refreshButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: ""
            tooltipText: "Rescan library"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            fontSize: Style.font.iconSmall
            onClicked: root.refresh()
          }
        }

        // ---------- Games ----------
        Repeater {
          model: root.games

          Item {
            id: row
            required property var modelData
            required property int index

            width: column.width
            implicitHeight: Math.max(cover.height, labels.implicitHeight) + Style.space(10)

            readonly property bool hot: mouse.containsMouse || root.cursor === index

            Rectangle {
              anchors.fill: parent
              color: row.hot ? Style.hoverFill : "transparent"
            }

            // Steam caches portrait art for everything in the library, but a
            // game added seconds ago may not have it yet — fall back to a
            // glyph tile so the row keeps its shape either way.
            Item {
              id: cover
              anchors.left: parent.left
              anchors.leftMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              width: root.showCovers ? Style.space(30) : 0
              height: root.showCovers ? Style.space(45) : 0
              visible: root.showCovers

              Rectangle {
                anchors.fill: parent
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                visible: art.status !== Image.Ready

                Text {
                  anchors.centerIn: parent
                  text: ""
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.iconSmall
                }
              }

              Image {
                id: art
                anchors.fill: parent
                source: row.modelData.cover ? "file://" + row.modelData.cover : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                smooth: true
              }
            }

            Column {
              id: labels
              anchors.left: cover.visible ? cover.right : parent.left
              anchors.leftMargin: Style.space(10)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: row.modelData.name
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: Model.metaLabel(row.modelData, root.now)
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.cursor = row.index
              // Without this the row the pointer last crossed stays lit after
              // the pointer has left the list entirely.
              onExited: if (root.cursor === row.index) root.cursor = -1
              onClicked: root.launch(row.modelData)
            }
          }
        }

        // ---------- Empty state ----------
        Text {
          width: parent.width
          visible: root.loaded && root.games.length === 0
          text: "No Steam games installed"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          topPadding: Style.space(4)
          bottomPadding: Style.space(4)
        }

        PanelSeparator {
          width: parent.width
          foreground: root.contentForeground
        }

        // ---------- Footer: the whole library ----------
        Item {
          width: parent.width
          implicitHeight: libraryLabel.implicitHeight + Style.space(10)

          readonly property bool hot: libraryMouse.containsMouse

          Rectangle {
            anchors.fill: parent
            color: parent.hot ? Style.hoverFill : "transparent"
          }

          Text {
            id: libraryLabel
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            text: "   Open Steam library"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          MouseArea {
            id: libraryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openLibrary()
          }
        }
      }
    }
  }
}
