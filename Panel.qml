import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "obsidian_json.js" as Oj

Panel {
    id: root
    moduleName: "rafael.omarchy-obsidian-panel"
    ipcTarget: "rafael.omarchy-obsidian-panel"
    manageIpc: false

    readonly property string obsidianConfigPath: root.obsidianConfigDir + "/obsidian.json"
    property var vaults: []
    property int selectedIndex: 0
    property bool cursorActive: false
    readonly property bool searching: searchInput.text.trim().length > 0
    readonly property var vaultListWithCreate: {
        var base = root.vaults || []
        if (root.searching) return base
        return base.concat([{ kind: "create" }])
    }
    readonly property var visibleItems: searching ? noteSearch.results : vaultListWithCreate

    property bool formMode: false
    property string formName: ""
    property string formParentDir: ""
    property string formError: ""
    property bool formBusy: false
    property string _pendingParent: ""

    readonly property var blockedParentPrefixes: [
        "/etc/", "/usr/", "/bin/", "/sbin/", "/var/", "/opt/", "/root/",
        "/boot/", "/sys/", "/proc/", "/dev/", "/lib/", "/lib64/", "/run/"
    ]
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string obsidianConfigDir: setting("obsidianConfigDir",
        (Quickshell.env("XDG_CONFIG_HOME") || homeDir + "/.config") + "/obsidian")
    readonly property bool autoOpenAfterCreate: setting("autoOpenAfterCreate", true)

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
        var item = visibleItems[selectedIndex]
        if (item && item.kind === "create") {
            enterCreateForm()
            return
        }
        if (searching) openNote(item)
        else openVault(item)
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

    function enterCreateForm() {
        root.formMode = true
        root.formError = ""
        root.formName = ""
        root.formParentDir = ""
        Qt.callLater(function() { formNameField.forceActiveFocus() })
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
        tooltipText: "Obsidian Vaults"
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
        focusTarget: root.formMode ? formNameField : searchInput
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
                visible: !root.formMode
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

            PanelSeparator { visible: !root.formMode; foreground: root.bar.foreground }

            QQC.ScrollView {
                id: resultScroll
                visible: !root.formMode
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
                            readonly property bool isCreateRow: modelData && modelData.kind === "create"
                            readonly property bool selected: root.cursorActive && root.selectedIndex === index
                            implicitHeight: content.implicitHeight + Style.space(12)
                            hasCursor: selected && !isCreateRow
                            foreground: root.bar.foreground
                            fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
                            currentFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
                            visible: !isCreateRow
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
                                    visible: !row.isCreateRow
                                    text: root.searching ? row.modelData.title : (row.modelData.name || "")
                                    color: root.bar.foreground
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.body
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: root.searching && !row.isCreateRow
                                    width: parent.width
                                    textFormat: Text.RichText
                                    text: "<b>" + root.escapeHtml(row.modelData.vaultName || "") + "</b>  "
                                          + root.escapeHtml(row.modelData.directory || "")
                                    color: Qt.darker(root.bar.foreground, 1.35)
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.bodySmall
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                    CursorSurface {
                        id: createRow
                        width: listContent.width
                        visible: !root.searching
                        implicitHeight: triggerLabel.implicitHeight + Style.space(12)
                        readonly property int myIndex: root.vaults.length
                        readonly property bool selected: root.cursorActive && root.selectedIndex === myIndex
                        hasCursor: selected
                        foreground: root.bar.foreground
                        fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
                        currentFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse) root.selectRow(parent.myIndex)
                            onClicked: root.enterCreateForm()
                        }
                        Text {
                            id: triggerLabel
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Style.space(10)
                            text: "+ Create new vault"
                            color: Qt.darker(root.bar.foreground, 1.15)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.body
                            font.italic: true
                        }
                    }
                }
            }

            Text {
                visible: root.searching && !noteSearch.running && noteSearch.results.length === 0 && !root.formMode
                text: "No matching notes"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                width: parent.width
                leftPadding: Style.space(10)
            }
            Text {
                visible: !root.searching && root.vaults.length === 0 && !root.formMode
                text: "No vaults found"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                width: parent.width
                leftPadding: Style.space(10)
            }
            Column {
                id: formView
                width: parent.width
                visible: root.formMode
                spacing: Style.space(8)

                Text {
                    width: parent.width
                    leftPadding: Style.space(10)
                    text: "CREATE VAULT"
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                TextField {
                    id: formNameField
                    width: parent.width
                    foreground: root.bar.foreground
                    accent: Color.accent
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    placeholderText: "Vault name"
                    text: root.formName
                    onTextChanged: root.formName = text
                    focus: root.formMode && root.opened
                    activeFocusOnTab: true
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) { root.cancelForm(); event.accepted = true }
                        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                 && root.formName.trim() !== "" && !root.formBusy) {
                            root.submitForm(); event.accepted = true
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Style.space(6)
                    TextField {
                        id: formDirField
                        width: parent.width - parent.spacing - browseBtn.width
                        foreground: root.bar.foreground
                        accent: Color.accent
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        placeholderText: "Parent directory (e.g. /home/you/Documents/Vaults)"
                        text: root.formParentDir
                        onTextChanged: root.formParentDir = text
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) { root.cancelForm(); event.accepted = true }
                        }
                    }
                    BarIconButton {
                        id: browseBtn
                        bar: root.bar
                        text: "…"
                        tooltipText: "Browse for parent directory"
                        onPressed: function(b) { root.openFolderPicker() }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Rectangle {
                        id: createBtn
                        width: parent.width * 0.5 - parent.spacing / 2
                        height: Style.font.body + Style.space(12)
                        color: root.formBusy ? Qt.darker(Color.accent, 1.6) : Color.accent
                        radius: Style.cornerRadius
                        Text {
                            anchors.centerIn: parent
                            text: root.formBusy ? "Creating…" : "Create"
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.body
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: root.formBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: if (!root.formBusy && root.formName.trim() !== "") root.submitForm()
                        }
                    }
                    Rectangle {
                        id: cancelBtn
                        width: parent.width * 0.5 - parent.spacing / 2
                        height: Style.font.body + Style.space(12)
                        color: Qt.alpha(root.bar.foreground, 0.12)
                        radius: Style.cornerRadius
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.body
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelForm()
                        }
                    }
                }

                Text {
                    visible: root.formError !== ""
                    width: parent.width
                    leftPadding: Style.space(10)
                    text: root.formError
                    color: Color.urgent
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    function escapeHtml(value) {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                            .replace(/>/g, "&gt;").replace(/"/g, "&quot;")
    }

    function cancelForm() {
        if (root.formBusy) {
            root.formError = "Cannot cancel while creating…"
            return
        }
        root.formMode = false
        root.formError = ""
        root.formName = ""
        root.formParentDir = ""
        searchInput.forceActiveFocus()
    }

    function submitForm() {
        if (root.formBusy) return
        var name = root.formName.trim()
        var parent = root.formParentDir.trim()
        if (name === "") { root.formError = "Name is required"; return }
        if (parent === "") { root.formError = "Parent directory is required"; return }
        if (!parent.startsWith("/")) { root.formError = "Parent directory must be an absolute path"; return }
        if (/[\\/]/.test(name)) { root.formError = "Name cannot contain '/'"; return }
        if (name === "." || name === "..") { root.formError = "Invalid name"; return }
        var normalized = parent
        while (normalized.length > 1 && normalized.endsWith("/"))
            normalized = normalized.substring(0, normalized.length - 1)
        while (normalized !== "/" && normalized.endsWith("/."))
            normalized = normalized.substring(0, normalized.length - 2)
        while (normalized !== "/" && normalized.endsWith("/..")) {
            var idx = normalized.lastIndexOf("/")
            if (idx <= 0) { normalized = "/"; break }
            normalized = normalized.substring(0, idx)
            var idx2 = normalized.lastIndexOf("/")
            if (idx2 < 0) { normalized = "/"; break }
            normalized = normalized.substring(0, idx2)
        }
        if (normalized === "") { normalized = "/" }
        if (normalized === "/") { root.formError = "Parent directory cannot be the filesystem root"; return }
        var blocked = false
        for (var i = 0; i < root.blockedParentPrefixes.length; ++i) {
            var stripped = root.blockedParentPrefixes[i].replace(/\/$/, "")
            if (normalized === stripped || normalized.startsWith(root.blockedParentPrefixes[i])) {
                blocked = true; break
            }
        }
        if (blocked) { root.formError = "Parent directory is in a protected system location"; return }
        if (normalized === root.obsidianConfigDir
            || normalized.startsWith(root.obsidianConfigDir + "/")) {
            root.formError = "Parent directory cannot be Obsidian's own config folder"; return }
        if (normalized === "") { normalized = "/" }
        for (var p = 0; p < root.vaults.length; ++p) {
            if (root.vaults[p].path === normalized + "/" + name) {
                root.formError = "A vault with that path already exists"; return }
        }
        root.formBusy = true
        root.formError = ""
        root._pendingParent = normalized
        mkdirProcess.command = ["mkdir", "-p", normalized + "/" + name]
        mkdirProcess.running = true
    }

    function openFolderPicker() {
        pickerDialog.open()
    }

    Process {
        id: mkdirProcess
        running: false
        command: ["true"]
        onExited: function(code) {
            if (code !== 0) {
                root.formBusy = false
                root.formError = "mkdir failed (exit " + code + ")"
                return
            }
            var fullPath = root._pendingParent + "/" + root.formName.trim()
            vaultCreator.vaultId = Oj.generateVaultId()
            vaultCreator.vaultPath = fullPath
            vaultCreator.ts = Date.now()
            vaultCreator.start()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (root.mkdirProcess.exitCode !== 0 && this.text.length > 0) {
                    root.formError = "mkdir: " + this.text.trim()
                }
            }
        }
    }

    VaultCreator {
        id: vaultCreator
        configPath: root.obsidianConfigPath
        onDone: function(success, message) {
            root.formBusy = false
            if (!success) {
                root.formError = message
                return
            }
            var vaultName = root.formName.trim()
            root.formMode = false
            root.formName = ""
            root.formParentDir = ""
            if (root.autoOpenAfterCreate) {
                Quickshell.execDetached(["obsidian",
                    "obsidian://open?vault=" + encodeURIComponent(vaultName)])
            }
            vaultFile.reload()
            root.close()
        }
    }

    FolderDialog {
        id: pickerDialog
        title: "Choose vault parent directory"
        onAccepted: {
            var url = selectedFolder.toString()
            var path = decodeURIComponent(url.replace(/^file:\/\//, ""))
            root.formParentDir = path
        }
    }
}
