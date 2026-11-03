import Cocoa

final class AtalhosWindows: Feature {
    private struct Traducao {
        let tecla: Int64
        let flags: CGEventFlags
    }

    private let home: Int64 = 115
    private let fim: Int64 = 119
    private let esquerda: Int64 = 123
    private let direita: Int64 = 124
    private let baixo: Int64 = 125
    private let cima: Int64 = 126
    private let apagar: Int64 = 51
    private let apagarFrente: Int64 = 117
    private let f4: Int64 = 118
    private let letraW: Int64 = 13

    private var tap: EventTap?
    private var emAndamento: [Int64: Traducao] = [:]

    init() {
        super.init(chave: "atalhosWindows", titulo: "Atalhos do Windows (Home/End, Ctrl+setas, Alt+F4…)", padrao: false)
    }

    override func ativar() -> Bool {
        tap = EventTap(eventos: [.keyDown, .keyUp]) { [weak self] tipo, evento in
            self?.tratar(tipo, evento) ?? evento
        }
        return tap?.valido ?? false
    }

    override func desativar() {
        tap = nil
        emAndamento.removeAll()
    }

    private func tratar(_ tipo: CGEventType, _ evento: CGEvent) -> CGEvent? {
        let tecla = evento.getIntegerValueField(.keyboardEventKeycode)
        if tipo == .keyUp {
            if let t = emAndamento.removeValue(forKey: tecla) { aplicar(t, em: evento) }
            return evento
        }
        guard let t = traduzir(tecla, evento.flags) else { return evento }
        emAndamento[tecla] = t
        aplicar(t, em: evento)
        return evento
    }

    private func aplicar(_ t: Traducao, em evento: CGEvent) {
        evento.setIntegerValueField(.keyboardEventKeycode, value: t.tecla)
        evento.flags = t.flags
    }

    private func traduzir(_ tecla: Int64, _ flags: CGEventFlags) -> Traducao? {
        let cmd = flags.contains(.maskCommand)
        let alt = flags.contains(.maskAlternate)
        let ctrl = flags.contains(.maskControl)
        let comCmdTrocadoPorAlt = flags.subtracting(.maskCommand).union(.maskAlternate)

        if (tecla == home || tecla == fim) && !cmd && !alt && !ctrl {
            return Traducao(tecla: tecla == home ? esquerda : direita, flags: flags.union(.maskCommand))
        }
        if (tecla == home || tecla == fim) && cmd && !alt && !ctrl {
            return Traducao(tecla: tecla == home ? cima : baixo, flags: flags)
        }
        if (tecla == esquerda || tecla == direita || tecla == apagar || tecla == apagarFrente) && cmd && !alt && !ctrl {
            return Traducao(tecla: tecla, flags: comCmdTrocadoPorAlt)
        }
        if tecla == f4 && alt && !cmd && !ctrl {
            return Traducao(tecla: letraW, flags: flags.subtracting(.maskAlternate).union(.maskCommand))
        }
        return nil
    }
}
