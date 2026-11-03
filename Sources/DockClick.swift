import Cocoa
import ApplicationServices

final class DockClick: Feature {
    private enum Acao {
        case minimizar([AXUIElement])
        case restaurar([AXUIElement], NSRunningApplication)
    }

    private var tap: EventTap?
    private var pendente: Acao?
    private var ultimaAcao = Date.distantPast

    init() {
        super.init(chave: "dockClick", titulo: "Clique no Dock minimiza e restaura o app")
    }

    override func ativar() -> Bool {
        tap = EventTap(eventos: [.leftMouseDown, .leftMouseUp]) { [weak self] tipo, evento in
            self?.tratar(tipo, evento)
            return evento
        }
        return tap?.valido ?? false
    }

    override func desativar() {
        tap = nil
        pendente = nil
    }

    private func tratar(_ tipo: CGEventType, _ evento: CGEvent) {
        if tipo == .leftMouseUp {
            if let acao = pendente {
                pendente = nil
                executar(acao)
            }
            return
        }

        pendente = nil
        let pos = evento.location
        guard Date().timeIntervalSince(ultimaAcao) > 0.6,
              naFaixaDoDock(pos), let item = itemDoDock(em: pos), let app = aplicativo(de: item) else { return }

        let janelas = AX.janelas(app)
        let visiveis = janelas.filter { !AX.minimizada($0) && AX.ehPadrao($0) }
        let minimizadas = janelas.filter { AX.minimizada($0) }

        if app.isActive && !visiveis.isEmpty {
            pendente = .minimizar(visiveis)
        } else if visiveis.isEmpty && !minimizadas.isEmpty {
            pendente = .restaurar(minimizadas, app)
        }
    }

    private func executar(_ acao: Acao) {
        ultimaAcao = Date()
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.08) {
            switch acao {
            case .minimizar(let janelas):
                janelas.forEach { AX.minimizar($0, true) }
            case .restaurar(let janelas, let app):
                janelas.forEach { AX.minimizar($0, false) }
                DispatchQueue.main.async { app.activate(options: [.activateIgnoringOtherApps]) }
            }
        }
    }

    private func naFaixaDoDock(_ pos: CGPoint) -> Bool {
        guard let altura = NSScreen.screens.first?.frame.height else { return false }
        let p = CGPoint(x: pos.x, y: altura - pos.y)
        guard let tela = NSScreen.screens.first(where: { $0.frame.contains(p) }) else { return false }
        let f = tela.frame
        return p.y - f.minY < 150 || p.x - f.minX < 150 || f.maxX - p.x < 150
    }

    private func itemDoDock(em pos: CGPoint) -> AXUIElement? {
        var elemento: AXUIElement?
        let sistema = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(sistema, Float(pos.x), Float(pos.y), &elemento) == .success,
              let el = elemento else { return nil }
        let sub: String? = AX.atributo(el, kAXSubroleAttribute)
        return sub == "AXApplicationDockItem" ? el : nil
    }

    private func aplicativo(de item: AXUIElement) -> NSRunningApplication? {
        let url: URL? = AX.atributo(item, kAXURLAttribute)
        guard let caminho = url?.standardizedFileURL.path else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.standardizedFileURL.path == caminho
        }
    }
}
