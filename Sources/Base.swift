import Cocoa
import ApplicationServices

class Feature {
    let chave: String
    let titulo: String
    let padrao: Bool
    var ativo = false

    init(chave: String, titulo: String, padrao: Bool = true) {
        self.chave = chave
        self.titulo = titulo
        self.padrao = padrao
    }

    func ativar() -> Bool { false }
    func desativar() {}
}

enum Pref {
    static func bool(_ chave: String, padrao: Bool = true) -> Bool {
        (UserDefaults.standard.object(forKey: chave) as? Bool) ?? padrao
    }

    static func definir(_ chave: String, _ valor: Bool) {
        UserDefaults.standard.set(valor, forKey: chave)
    }
}

enum Registro {
    static let caminho = NSHomeDirectory() + "/Library/Logs/ModoPC.log"

    static func escrever(_ texto: String) {
        let formato = DateFormatter()
        formato.dateFormat = "HH:mm:ss.SSS"
        let linha = "\(formato.string(from: Date())) \(texto)\n"
        if let dados = linha.data(using: .utf8) {
            if let f = FileHandle(forWritingAtPath: caminho) {
                f.seekToEndOfFile(); f.write(dados); f.closeFile()
            } else {
                try? dados.write(to: URL(fileURLWithPath: caminho))
            }
        }
    }
}

enum Shell {
    @discardableResult
    static func rodar(_ caminho: String, _ argumentos: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: caminho)
        p.arguments = argumentos
        let saida = Pipe()
        p.standardOutput = saida
        p.standardError = Pipe()
        do { try p.run() } catch { return "" }
        let dados = saida.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: dados, encoding: .utf8) ?? ""
    }
}

final class EventTap {
    private var tap: CFMachPort?
    private var fonte: CFRunLoopSource?
    private let tratador: (CGEventType, CGEvent) -> CGEvent?

    init(eventos: [CGEventType], tratador: @escaping (CGEventType, CGEvent) -> CGEvent?) {
        self.tratador = tratador
        var mascara: CGEventMask = 0
        for e in eventos { mascara |= CGEventMask(1) << CGEventMask(e.rawValue) }
        let retorno: CGEventTapCallBack = { _, tipo, evento, info in
            guard let info = info else { return Unmanaged.passUnretained(evento) }
            let eu = Unmanaged<EventTap>.fromOpaque(info).takeUnretainedValue()
            if tipo == .tapDisabledByTimeout || tipo == .tapDisabledByUserInput {
                if let t = eu.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(evento)
            }
            guard let saida = eu.tratador(tipo, evento) else { return nil }
            return Unmanaged.passUnretained(saida)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mascara, callback: retorno,
                                userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let t = tap {
            fonte = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), fonte, .commonModes)
            CGEvent.tapEnable(tap: t, enable: true)
        }
    }

    var valido: Bool { tap != nil }

    deinit {
        if let f = fonte { CFRunLoopRemoveSource(CFRunLoopGetMain(), f, .commonModes) }
        if let t = tap { CFMachPortInvalidate(t) }
    }
}

enum AX {
    static func atributo<T>(_ el: AXUIElement, _ nome: String) -> T? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, nome as CFString, &v) == .success else { return nil }
        return v as? T
    }

    static func janelas(_ app: NSRunningApplication) -> [AXUIElement] {
        let el = AXUIElementCreateApplication(app.processIdentifier)
        let lista: [AXUIElement]? = atributo(el, kAXWindowsAttribute)
        return lista ?? []
    }

    static func ehPadrao(_ janela: AXUIElement) -> Bool {
        let sub: String? = atributo(janela, kAXSubroleAttribute)
        return sub == kAXStandardWindowSubrole
    }

    static func minimizada(_ janela: AXUIElement) -> Bool {
        let m: Bool? = atributo(janela, kAXMinimizedAttribute)
        return m ?? false
    }

    @discardableResult
    static func minimizar(_ janela: AXUIElement, _ ligado: Bool) -> AXError {
        AXUIElementSetAttributeValue(janela, kAXMinimizedAttribute as CFString, ligado ? kCFBooleanTrue : kCFBooleanFalse)
    }

    static func trazerAFrente(_ janela: AXUIElement) {
        AXUIElementPerformAction(janela, kAXRaiseAction as CFString)
    }

    static func restaurarSeSoMinimizadas(_ app: NSRunningApplication, tentativa: Int = 0) {
        if app.isHidden { app.unhide() }
        let todas = janelas(app)
        if !todas.isEmpty {
            if todas.contains(where: { !minimizada($0) && ehPadrao($0) }) { return }
            if let primeira = todas.first(where: { minimizada($0) }) {
                minimizar(primeira, false)
                trazerAFrente(primeira)
            }
            return
        }
        guard tentativa < 8 else { reabrir(app); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            restaurarSeSoMinimizadas(app, tentativa: tentativa + 1)
        }
    }

    static func reabrir(_ app: NSRunningApplication) {
        guard let url = app.bundleURL else { return }
        let configuracao = NSWorkspace.OpenConfiguration()
        configuracao.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuracao, completionHandler: nil)
    }
}
