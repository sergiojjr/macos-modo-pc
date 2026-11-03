import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let altTab = AltTab()
    private lazy var funcoes: [Feature] = [DockClick(), UpdateBadge(), altTab, AutoScroll(), TecladoPC(), AtalhosWindows()]
    private var vigia: Timer?
    private let idAgente = "com.modopc.app"

    func applicationDidFinishLaunching(_ notificacao: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--demo-alttab") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.altTab.demonstrar() }
            return
        }
        let opcoes = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opcoes)
        _ = CGRequestListenEventAccess()

        statusItem.button?.image = AppDelegate.iconeWindows()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        reconciliar()
        vigia = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.reconciliar() }
    }

    private static func iconeWindows() -> NSImage {
        let imagem = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            let lado: CGFloat = 7.5, espaco: CGFloat = 1.5
            let origem = (18 - 2 * lado - espaco) / 2
            for i in 0..<2 {
                for j in 0..<2 {
                    let x = origem + CGFloat(i) * (lado + espaco)
                    let y = origem + CGFloat(j) * (lado + espaco)
                    NSBezierPath(rect: NSRect(x: x, y: y, width: lado, height: lado)).fill()
                }
            }
            return true
        }
        imagem.isTemplate = true
        return imagem
    }

    private func reconciliar() {
        for f in funcoes {
            let desejada = Pref.bool(f.chave, padrao: f.padrao)
            if desejada && !f.ativo {
                f.ativo = f.ativar()
            } else if !desejada && f.ativo {
                f.desativar()
                f.ativo = false
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let confiavel = AXIsProcessTrusted()
        if !confiavel {
            let aviso = NSMenuItem(title: "⚠︎ Permissão de Acessibilidade pendente", action: nil, keyEquivalent: "")
            aviso.isEnabled = false
            menu.addItem(aviso)
            menu.addItem(NSMenuItem.separator())
        }
        for (i, f) in funcoes.enumerated() {
            let item = NSMenuItem(title: f.titulo, action: #selector(alternar(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.state = Pref.bool(f.chave, padrao: f.padrao) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(itemAcao("Usar layout de teclado ABNT2", #selector(usarABNT2)))
        menu.addItem(NSMenuItem.separator())
        let login = itemAcao("Abrir ao iniciar sessão", #selector(alternarLogin))
        login.state = FileManager.default.fileExists(atPath: caminhoAgente) ? .on : .off
        menu.addItem(login)
        menu.addItem(itemAcao("Abrir ajustes de Acessibilidade…", #selector(abrirAcessibilidade)))
        menu.addItem(itemAcao("Abrir ajustes de Monitoramento de Entrada…", #selector(abrirMonitoramento)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(itemAcao("Sair do Modo PC", #selector(sair)))
    }

    private func itemAcao(_ titulo: String, _ acao: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: titulo, action: acao, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func alternar(_ item: NSMenuItem) {
        let f = funcoes[item.tag]
        Pref.definir(f.chave, !Pref.bool(f.chave, padrao: f.padrao))
        reconciliar()
    }

    @objc private func usarABNT2() {
        if !LayoutABNT2.selecionar() {
            let alerta = NSAlert()
            alerta.messageText = "Não foi possível ativar o layout ABNT2."
            alerta.informativeText = "Adicione \"Português – Brasil (ABNT2)\" em Ajustes do Sistema → Teclado → Fontes de Entrada."
            alerta.runModal()
        }
    }

    private var caminhoAgente: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(idAgente).plist"
    }

    @objc private func alternarLogin() {
        if FileManager.default.fileExists(atPath: caminhoAgente) {
            Shell.rodar("/bin/launchctl", ["bootout", "gui/\(getuid())/\(idAgente)"])
            try? FileManager.default.removeItem(atPath: caminhoAgente)
            return
        }
        guard let executavel = Bundle.main.executablePath else { return }
        let plist: [String: Any] = ["Label": idAgente, "ProgramArguments": [executavel], "RunAtLoad": true, "KeepAlive": false]
        (plist as NSDictionary).write(toFile: caminhoAgente, atomically: true)
    }

    @objc private func abrirAcessibilidade() {
        abrir("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @objc private func abrirMonitoramento() {
        abrir("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func abrir(_ url: String) {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }

    @objc private func sair() {
        funcoes.filter { $0.ativo }.forEach { $0.desativar() }
        NSApp.terminate(nil)
    }
}

let aplicativo = NSApplication.shared
let delegado = AppDelegate()
aplicativo.delegate = delegado
aplicativo.run()
