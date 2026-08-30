import QtQuick
import Quickshell
import Quickshell.Io
import "obsidian_json.js" as Oj

Item {
    id: root
    property string vaultId: ""
    property string vaultPath: ""
    property int ts: 0
    property string configPath: ""
    signal done(bool success, string message)

    readonly property string tmpPath: configPath + ".tmp"

    FileView {
        id: configView
        path: root.configPath
        onLoaded: {
            try {
                var parsed = JSON.parse(configView.text() || "{}")
                var merged = Oj.mergeVaultEntry(parsed, root.vaultId, root.vaultPath, root.ts)
                var json = JSON.stringify(merged, null, 2)
                var escaped = json.replace(/'/g, "'\\''")
                writerProcess.command = ["sh", "-c",
                    "printf '%s' '" + escaped + "' > " + root.tmpPath
                    + " && mv -f " + root.tmpPath + " " + root.configPath]
                writerProcess.running = true
            } catch (e) {
                root.done(false, "Parse/merge failed: " + e)
            }
        }
        onLoadFailed: function(err) {
            root.done(false, "Failed to read obsidian.json: " + err)
        }
    }

    Process {
        id: writerProcess
        running: false
        command: ["true"]
        onExited: function(code) {
            if (code === 0) {
                configView.reload()
                root.done(true, "")
            } else {
                root.done(false, "Atomic write failed (exit " + code + ")")
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (writerProcess.exitCode !== 0 && this.text.length > 0) {
                    root.done(false, "stderr: " + this.text.trim())
                }
            }
        }
    }

    function start() {
        if (root.configPath === "") {
            root.done(false, "configPath not provided")
            return
        }
        if (root.vaultId === "" || root.vaultPath === "" || root.ts === 0) {
            root.done(false, "VaultCreator not initialized")
            return
        }
        configView.reload()
    }
}