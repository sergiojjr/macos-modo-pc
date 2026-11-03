import Cocoa

private final class VisaoInvertida: NSView {
    override var isFlipped: Bool { true }
}

final class PainelAltTab: NSPanel {
    private let efeito = NSVisualEffectView()
    private let conteudo = VisaoInvertida()
    private let destaque = NSView()
    private let rotulo = NSTextField(labelWithString: "")
    private var escala: CGFloat = 1
    private var quantidade = 0

    private let padX: CGFloat = 20
    private let padY: CGFloat = 25
    private let item: CGFloat = 133
    private let icone: CGFloat = 104
    private let nomeAltura: CGFloat = 26

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        efeito.material = .hudWindow
        efeito.blendingMode = .behindWindow
        efeito.state = .active
        efeito.wantsLayer = true
        efeito.layer?.cornerRadius = 26
        efeito.layer?.masksToBounds = true
        contentView = efeito

        efeito.addSubview(conteudo)
        destaque.wantsLayer = true
        destaque.layer?.backgroundColor = NSColor(white: 0, alpha: 0.22).cgColor
        destaque.layer?.cornerRadius = 14
        rotulo.alignment = .center
        rotulo.font = NSFont.systemFont(ofSize: 16)
        rotulo.textColor = .labelColor
        rotulo.lineBreakMode = .byTruncatingTail
    }

    func montar(apps: [NSRunningApplication], selecionado: Int, tela: NSScreen) {
        quantidade = apps.count
        let larguraMax = tela.frame.width * 0.92
        escala = min(1, (larguraMax - padX * 2) / (CGFloat(apps.count) * item))
        let it = item * escala, ic = icone * escala, px = padX * escala, py = padY * escala, nh = nomeAltura * escala

        let largura = px * 2 + CGFloat(apps.count) * it
        let altura = py + it + nh
        let moldura = NSRect(x: tela.frame.midX - largura / 2, y: tela.frame.midY - altura / 2, width: largura, height: altura)
        setFrame(moldura, display: false)
        efeito.frame = NSRect(x: 0, y: 0, width: largura, height: altura)
        conteudo.frame = efeito.bounds

        conteudo.subviews.forEach { $0.removeFromSuperview() }
        destaque.frame = quadroDestaque(selecionado)
        conteudo.addSubview(destaque)
        for (i, app) in apps.enumerated() {
            let v = NSImageView(frame: NSRect(x: px + CGFloat(i) * it + (it - ic) / 2, y: py + (it - ic) / 2, width: ic, height: ic))
            v.image = app.icon
            v.imageScaling = .scaleProportionallyUpOrDown
            conteudo.addSubview(v)
        }
        rotulo.font = NSFont.systemFont(ofSize: 16 * max(escala, 0.75))
        rotulo.stringValue = apps[selecionado].localizedName ?? ""
        rotulo.frame = quadroRotulo(selecionado)
        conteudo.addSubview(rotulo)
    }

    func selecionar(_ indice: Int, nome: String) {
        rotulo.stringValue = nome
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.07
            destaque.animator().frame = quadroDestaque(indice)
        }
        rotulo.frame = quadroRotulo(indice)
    }

    private func quadroDestaque(_ i: Int) -> NSRect {
        let it = item * escala
        return NSRect(x: padX * escala + CGFloat(i) * it, y: padY * escala, width: it, height: it)
    }

    private func quadroRotulo(_ i: Int) -> NSRect {
        let it = item * escala
        let largura = 260 * escala
        let centro = padX * escala + CGFloat(i) * it + it / 2
        let total = padX * escala * 2 + CGFloat(quantidade) * it
        let x = max(0, min(total - largura, centro - largura / 2))
        return NSRect(x: x, y: padY * escala + it + 2, width: largura, height: nomeAltura * escala)
    }
}

final class AltTab: Feature {
    private var tap: EventTap?
    private var mru: [NSRunningApplication] = []
    private var apps: [NSRunningApplication] = []
    private var observadores: [NSObjectProtocol] = []
    private var painel: PainelAltTab?
    private var aberto = false
    private var selecionado = 0

    init() {
        super.init(chave: "altTab", titulo: "Alt+Tab no estilo do Cmd+Tab da Apple")
    }

    override func ativar() -> Bool {
        inicializarMRU()
        tap = EventTap(eventos: [.keyDown, .flagsChanged]) { [weak self] tipo, evento in
            self?.tratar(tipo, evento) ?? evento
        }
        guard tap?.valido == true else { tap = nil; return false }

        let centro = NSWorkspace.shared.notificationCenter
        observadores.append(centro.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { self?.registrar(app) }
        })
        observadores.append(centro.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { self?.remover(app) }
        })
        return true
    }

    override func desativar() {
        fechar()
        tap = nil
        observadores.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observadores.removeAll()
    }

    func demonstrar() {
        inicializarMRU()
        abrir(reverso: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.passo(1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.fechar() }
    }

    private func inicializarMRU() {
        let frente = NSWorkspace.shared.frontmostApplication
        mru = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0 != frente }
        if let f = frente, f.activationPolicy == .regular { mru.insert(f, at: 0) }
    }

    private func registrar(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        remover(app)
        mru.insert(app, at: 0)
    }

    private func remover(_ app: NSRunningApplication) {
        mru.removeAll { $0.processIdentifier == app.processIdentifier }
    }

    private func tratar(_ tipo: CGEventType, _ evento: CGEvent) -> CGEvent? {
        let flags = evento.flags
        let alt = flags.contains(.maskAlternate)
        if tipo == .flagsChanged {
            if aberto && !alt { escolher() }
            return evento
        }
        guard tipo == .keyDown else { return evento }
        let tecla = evento.getIntegerValueField(.keyboardEventKeycode)
        if tecla == 48 && alt && !flags.contains(.maskCommand) && !flags.contains(.maskControl) {
            let shift = flags.contains(.maskShift)
            if aberto { passo(shift ? -1 : 1) } else { abrir(reverso: shift) }
            return nil
        }
        if aberto {
            switch tecla {
            case 124: passo(1); return nil
            case 123: passo(-1); return nil
            case 36, 76: escolher(); return nil
            case 53: fechar(); return nil
            default: break
            }
        }
        return evento
    }

    private func abrir(reverso: Bool) {
        apps = mru.filter { !$0.isTerminated }
        guard !apps.isEmpty else { return }
        selecionado = apps.count > 1 ? 1 : 0
        let posicao = NSEvent.mouseLocation
        let tela = NSScreen.screens.first(where: { NSMouseInRect(posicao, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let p = painel ?? PainelAltTab()
        painel = p
        p.montar(apps: apps, selecionado: selecionado, tela: tela)
        p.orderFrontRegardless()
        aberto = true
        if reverso { passo(-1) }
    }

    private func passo(_ direcao: Int) {
        guard aberto, !apps.isEmpty else { return }
        selecionado = ((selecionado + direcao) % apps.count + apps.count) % apps.count
        painel?.selecionar(selecionado, nome: apps[selecionado].localizedName ?? "")
    }

    private func fechar() {
        aberto = false
        painel?.orderOut(nil)
    }

    private func escolher() {
        guard aberto else { return }
        let app = apps.indices.contains(selecionado) ? apps[selecionado] : nil
        fechar()
        guard let alvo = app else { return }
        alvo.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { AX.restaurarSeSoMinimizadas(alvo) }
    }
}
