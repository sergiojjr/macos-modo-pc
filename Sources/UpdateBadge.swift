import Cocoa

final class UpdateBadge: Feature {
    private var timer: Timer?

    init() {
        super.init(chave: "updateBadge", titulo: "Esconder selo de atualização do macOS")
    }

    override func ativar() -> Bool {
        limpar()
        let t = Timer(timeInterval: 120, repeats: true) { [weak self] _ in self?.limpar() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        return true
    }

    override func desativar() {
        timer?.invalidate()
        timer = nil
    }

    private func limpar() {
        let atual = Shell.rodar("/usr/bin/defaults", ["read", "com.apple.systempreferences", "AttentionPrefBundleIDs"])
        guard atual.contains("softwareupdate") else { return }
        Shell.rodar("/usr/bin/defaults", ["write", "com.apple.systempreferences", "AttentionPrefBundleIDs", "0"])
        Shell.rodar("/usr/bin/killall", ["Dock"])
    }
}
