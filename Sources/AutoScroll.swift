import Cocoa

final class AutoScroll: Feature {
    private var tap: EventTap?
    private var ancora = CGPoint.zero
    private var moveu = false
    private var inicio = Date()
    private var timer: Timer?
    private let marca: Int64 = 0x4D50
    private let zonaMorta: CGFloat = 10
    private let fator: CGFloat = 0.45

    init() {
        super.init(chave: "autoScroll", titulo: "Rolagem automática (segurar botão do meio)")
    }

    override func ativar() -> Bool {
        tap = EventTap(eventos: [.otherMouseDown, .otherMouseUp]) { [weak self] tipo, evento in
            self?.tratar(tipo, evento) ?? evento
        }
        return tap?.valido ?? false
    }

    override func desativar() {
        parar()
        tap = nil
    }

    private func tratar(_ tipo: CGEventType, _ evento: CGEvent) -> CGEvent? {
        if evento.getIntegerValueField(.eventSourceUserData) == marca { return evento }
        guard evento.getIntegerValueField(.mouseEventButtonNumber) == 2 else { return evento }

        if tipo == .otherMouseDown {
            parar()
            ancora = evento.location
            moveu = false
            inicio = Date()
            let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.passo() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
            return nil
        }
        let foiClique = !moveu && Date().timeIntervalSince(inicio) < 0.3
        parar()
        if foiClique { repostarClique(evento.location) }
        return nil
    }

    private func parar() {
        timer?.invalidate()
        timer = nil
    }

    private func passo() {
        let atual = CGEvent(source: nil)?.location ?? ancora
        let dy = atual.y - ancora.y
        if abs(dy) < zonaMorta { return }
        moveu = true
        var valor = (abs(dy) - zonaMorta) * fator
        if dy > 0 { valor = -valor }
        let rolagem = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                              wheel1: Int32(valor.rounded()), wheel2: 0, wheel3: 0)
        rolagem?.post(tap: .cgSessionEventTap)
    }

    private func repostarClique(_ posicao: CGPoint) {
        for tipo in [CGEventType.otherMouseDown, CGEventType.otherMouseUp] {
            let e = CGEvent(mouseEventSource: nil, mouseType: tipo, mouseCursorPosition: posicao, mouseButton: .center)
            e?.setIntegerValueField(.eventSourceUserData, value: marca)
            e?.post(tap: .cgSessionEventTap)
        }
    }
}
