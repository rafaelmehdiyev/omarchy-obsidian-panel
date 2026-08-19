import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
    id: root
    moduleName: "rafael.omarchy-obsidian-panel"
    ipcTarget: "rafael.omarchy-obsidian-panel"
    manageIpc: false

    readonly property string obsidianConfigPath: Quickshell.env("HOME") + "/.config/obsidian/obsidian.json"
    property var vaults: []
    property int selectedIndex: 0
    property bool cursorActive: false
    readonly property bool searching: searchInput.text.trim().length > 0
    readonly property var visibleItems: searching ? noteSearch.results : vaults

    onOpenedChanged: {
        if (opened) {
            vaultFile.reload()
            selectedIndex = 0
            cursorActive = false
            searchInput.forceActiveFocus()
        }
    }

    FileView {
        id: vaultFile
        path: root.obsidianConfigPath
        onLoaded: {
            try {
                var data = JSON.parse(vaultFile.text())
                var result = []
                var vaultMap = data.vaults || {}
                for (var id in vaultMap) {
                    var path = vaultMap[id].path || ""
                    if (!path) continue
                    var uriName = path.split("/").pop()
                    result.push({ name: vaultMap[id].name || uriName, uriName: uriName, path: path })
                }
                result.sort(function(a, b) { return a.name.localeCompare(b.name) })
                root.vaults = result
            } catch (_) {
                root.vaults = []
            }
        }
    }

    VaultSearch {
        id: noteSearch
        vaults: root.vaults
        query: searchInput.text
        active: root.opened
    }

    function openVault(vault) {
        Quickshell.execDetached(["obsidian", "obsidian://open?vault=" + encodeURIComponent(vault.uriName)])
        root.close()
    }

    function openNote(note) {
        var url = "obsidian://open?vault=" + encodeURIComponent(note.vaultUriName)
                + "&file=" + encodeURIComponent(note.relativePath)
        Quickshell.execDetached(["obsidian", url])
        root.close()
    }

    function activateSelected() {
        if (!cursorActive || visibleItems.length === 0) return
        if (searching) openNote(visibleItems[selectedIndex])
        else openVault(visibleItems[selectedIndex])
    }

    function moveCursor(delta) {
        if (visibleItems.length === 0) return
        selectedIndex = Math.max(0, Math.min(visibleItems.length - 1, selectedIndex + delta))
        cursorActive = true
        Qt.callLater(ensureSelectedVisible)
    }

    function selectRow(index) {
        cursorActive = true
        selectedIndex = index
    }

    function ensureSelectedVisible() {
        var row = resultRepeater.itemAt(selectedIndex)
        var flickable = resultScroll.contentItem
        if (!row || !flickable || listContent.height <= resultScroll.availableHeight) return
        var top = flickable.contentY
        var bottom = top + flickable.height
        var newTop = top
        if (row.y < top) newTop = row.y
        else if (row.y + row.height > bottom) newTop = row.y + row.height - flickable.height
        if (newTop !== top) {
            var maximum = Math.max(0, flickable.contentHeight - flickable.height)
            flickable.contentY = Math.max(0, Math.min(maximum, newTop))
        }
    }

    implicitWidth: Style.bar.iconSlot
    implicitHeight: Style.bar.iconSlot

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: ""
        iconComponent: Component {
            Image {
                source: Qt.resolvedUrl("obsidian.svg")
                sourceSize.width: Style.bar.iconFont
                sourceSize.height: Style.bar.iconFont
                width: Style.bar.iconFont
                height: Style.bar.iconFont
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                fillMode: Image.Pad
                smooth: true
            }
        }
        onPressed: function(b) { root.toggle() }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: searchInput
        contentWidth: panel.fittedContentWidth(Style.space(360))
        contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

        Column {
            id: panelColumn
            anchors.fill: parent
            spacing: Style.space(8)

            Text {
                width: parent.width
                leftPadding: Style.space(10)
                text: "OBSIDIAN"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
            }

            TextField {
                id: searchInput
                width: parent.width
                foreground: root.bar.foreground
                accent: Color.accent
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                placeholderText: "Search notes in all vaults…"
                focus: true
                activeFocusOnTab: true
                onTextChanged: { root.selectedIndex = 0; root.cursorActive = false }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Down) { root.moveCursor(1); event.accepted = true }
                    else if (event.key === Qt.Key_Up) { root.moveCursor(-1); event.accepted = true }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activateSelected(); event.accepted = true }
                    else if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
                }
            }

            PanelSeparator { foreground: root.bar.foreground }

            QQC.ScrollView {
                id: resultScroll
                width: parent.width
                implicitHeight: Math.min(listContent.implicitHeight, Style.space(360))
                clip: true
                QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff

                Column {
                    id: listContent
                    width: resultScroll.availableWidth
                    Repeater {
                        id: resultRepeater
                        model: root.visibleItems
                        CursorSurface {
                            id: row
                            required property var modelData
                            required property int index
                            width: listContent.width
                            readonly property bool selected: root.cursorActive && root.selectedIndex === index
                            implicitHeight: content.implicitHeight + Style.space(12)
                            hasCursor: selected
                            foreground: root.bar.foreground
                            fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
                            currentFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: if (containsMouse) root.selectRow(row.index)
                                onClicked: {
                                    if (root.searching) root.openNote(row.modelData)
                                    else root.openVault(row.modelData)
                                }
                            }
                            Column {
                                id: content
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Style.space(10)
                                anchors.rightMargin: Style.space(10)
                                spacing: Style.space(2)
                                Text {
                                    width: parent.width
                                    text: root.searching ? row.modelData.title : row.modelData.name
                                    color: root.bar.foreground
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.body
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: root.searching
                                    width: parent.width
                                    textFormat: Text.RichText
                                    text: "<b>" + root.escapeHtml(row.modelData.vaultName) + "</b>  "
                                          + root.escapeHtml(row.modelData.directory)
                                    color: Qt.darker(root.bar.foreground, 1.35)
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.bodySmall
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.searching && !noteSearch.running && noteSearch.results.length === 0
                text: "No matching notes"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                width: parent.width
                leftPadding: Style.space(10)
            }
            Text {
                visible: !root.searching && root.vaults.length === 0
                text: "No vaults found"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                width: parent.width
                leftPadding: Style.space(10)
            }
        }
    }

    function escapeHtml(value) {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                            .replace(/>/g, "&gt;").replace(/\"/g, "&quot;")
    }
}
