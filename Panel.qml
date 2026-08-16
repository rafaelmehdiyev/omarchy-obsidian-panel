import QtQuick
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

                onOpenedChanged: {
                    if (opened)
                    {
                        vaultFile.reload()
                        selectedIndex = 0
                        cursorActive = false
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
                                var vaultPath = vaultMap[id].path || ""
                                if (vaultPath === "") continue
                                var parts = vaultPath.split("/")
                                var name = parts[parts.length - 1]
                                result.push({ name: name, path: vaultPath })
                            }
                            result.sort(function(a, b) { return a.name.localeCompare(b.name) })
                            root.vaults = result
                        } catch (_) {
                        root.vaults = []
                    }
                }
            }

            function openVault(vaultName)
            {
                Quickshell.execDetached(["obsidian", "obsidian://open?vault=" + vaultName])
                root.close()
            }

            function moveCursor(delta)
            {
                if (root.vaults.length === 0) return
                var next = root.selectedIndex + delta
                if (next < 0) next = 0
                if (next >= root.vaults.length) next = root.vaults.length - 1
                root.selectedIndex = next
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
                focusTarget: keyCatcher
                contentWidth: panel.fittedContentWidth(Style.space(280))
                contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

                PanelKeyCatcher {
                    id: keyCatcher
                    anchors.fill: parent

                    onMoveRequested: function(dx, dy) {
                    if (!root.cursorActive) {
                         root.cursorActive = true; return 
                    }
                    if (dy !== 0) root.moveCursor(dy)
                        }
                    onActivateRequested: {
                        if (!root.cursorActive || root.vaults.length === 0) return
                        root.openVault(root.vaults[root.selectedIndex].name)
                    }
                    onCloseRequested: root.close()

                    Column {
                        id: panelColumn
                        anchors.fill: parent
                        spacing: Style.space(8)

                        Item {
                            width: parent.width
                            implicitHeight: headerLabel.implicitHeight + Style.space(4)

                            Text {
                                id: headerLabel
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(10)
                                anchors.verticalCenter: parent.verticalCenter
                                text: "OBSIDIAN VAULTS"
                                color: Qt.darker(root.bar.foreground, 1.4)
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                font.letterSpacing: 1.2
                            }
                        }

                        PanelSeparator {
                            foreground: root.bar.foreground
                        }

                        Repeater {
                            model: root.vaults

                            CursorSurface {
                                id: vaultRow
                                required property var modelData
                                required property int index

                                width: panelColumn.width
                                implicitHeight: rowContent.implicitHeight + Style.space(12)

                                readonly property bool rowSelected: root.cursorActive && root.selectedIndex === index

                                    hasCursor: rowSelected
                                    foreground: root.bar.foreground
                                    fill: root.bar ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"
                                    currentFill: root.bar ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onContainsMouseChanged: {
                                            if (containsMouse)
                                            {
                                                root.cursorActive = true
                                                root.selectedIndex = vaultRow.index
                                            }
                                        }

                                        onClicked: root.openVault(vaultRow.modelData.name)
                                    }

                                    Item {
                                        id: rowContent
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: Style.space(10)
                                        anchors.rightMargin: Style.space(10)
                                        implicitHeight: Math.max(vaultIcon.implicitHeight, vaultName.implicitHeight)

                                        Text {
                                            id: vaultIcon
                                            text: ""
                                            color: root.bar.foreground
                                            font.family: root.bar.fontFamily
                                            font.pixelSize: Style.font.heading
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            id: vaultName
                                            text: vaultRow.modelData.name
                                            color: root.bar.foreground
                                            font.family: root.bar.fontFamily
                                            font.pixelSize: Style.font.body
                                            elide: Text.ElideRight
                                            anchors.left: vaultIcon.right
                                            anchors.leftMargin: Style.space(10)
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.vaults.length === 0
                                text: "No vaults found"
                                color: Qt.darker(root.bar.foreground, 1.5)
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.bodySmall
                                width: parent.width
                                leftPadding: Style.space(10)
                            }
                        }
                    }
                }
            }
