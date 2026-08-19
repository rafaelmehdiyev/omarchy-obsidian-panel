import QtQuick
import Quickshell.Io

Item {
    id: root
    required property var vaults
    required property string query
    required property bool active
    property var results: []
    readonly property bool running: searchProcess.running
    property int generation: 0

    onQueryChanged: schedule()
    onVaultsChanged: schedule()
    onActiveChanged: schedule()

    function schedule() {
        generation += 1
        results = []
        if (!active || query.trim().length === 0 || vaults.length === 0) {
            searchDebounce.stop()
            searchProcess.running = false
            return
        }
        searchDebounce.restart()
    }

    function searchCommand() {
        var command = ["find"]
        for (var i = 0; i < vaults.length; ++i) command.push(vaults[i].path)
        return command.concat(["-path", "*/.obsidian", "-prune", "-o", "-type", "f", "-iname", "*.md", "-print"])
    }

    function vaultForPath(path) {
        for (var i = 0; i < vaults.length; ++i)
            if (path.indexOf(vaults[i].path + "/") === 0) return vaults[i]
        return null
    }

    Timer {
        id: searchDebounce
        interval: 160
        repeat: false
        onTriggered: {
            if (!root.active || root.query.trim().length === 0) return
            searchProcess.running = false
            searchProcess.requestGeneration = root.generation
            searchProcess.command = root.searchCommand()
            searchProcess.running = true
        }
    }

    Process {
        id: searchProcess
        property int requestGeneration: 0
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (searchProcess.requestGeneration !== root.generation || !root.active) return
                var needle = root.query.trim().toLowerCase()
                var lines = this.text.split("\n")
                var found = []
                for (var i = 0; i < lines.length && found.length < 300; ++i) {
                    var path = lines[i]
                    if (!path) continue
                    var vault = root.vaultForPath(path)
                    if (!vault) continue
                    var relative = path.slice(vault.path.length + 1)
                    var filename = relative.split("/").pop()
                    var title = filename.replace(/\.md$/i, "")
                    if (title.toLowerCase().indexOf(needle) === -1) continue
                    var slash = relative.lastIndexOf("/")
                    found.push({ title: title, vaultName: vault.name, vaultUriName: vault.uriName,
                        relativePath: relative, directory: slash >= 0 ? relative.slice(0, slash) : "/" })
                }
                found.sort(function(a, b) {
                    var vaultOrder = a.vaultName.localeCompare(b.vaultName)
                    return vaultOrder !== 0 ? vaultOrder : a.relativePath.localeCompare(b.relativePath)
                })
                root.results = found
            }
        }
    }
}
