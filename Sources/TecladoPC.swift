import Cocoa
import Carbon.HIToolbox

final class TecladoPC: Feature {
    private var timer: Timer?
    private var aplicados: Set<String> = []

    private static let fabricanteApple = 0x05AC
    private static let mapeamento = """
    {"UserKeyMapping":[\
    {"HIDKeyboardModifierMappingSrc":30064771296,"HIDKeyboardModifierMappingDst":30064771299},\
    {"HIDKeyboardModifierMappingSrc":30064771299,"HIDKeyboardModifierMappingDst":30064771296},\
    {"HIDKeyboardModifierMappingSrc":30064771300,"HIDKeyboardModifierMappingDst":30064771303},\
    {"HIDKeyboardModifierMappingSrc":30064771303,"HIDKeyboardModifierMappingDst":30064771300}]}
    """
    private static let semMapeamento = "{\"UserKeyMapping\":[]}"

    init() {
        super.init(chave: "tecladoPC", titulo: "Teclado de PC: Ctrl ↔ Cmd e Win ↔ Ctrl")
    }

    override func ativar() -> Bool {
        varrer()
        let t = Timer(timeInterval: 3, repeats: true) { [weak self] _ in self?.varrer() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        return true
    }

    override func desativar() {
        timer?.invalidate()
        timer = nil
        for id in aplicados {
            let partes = id.split(separator: "-").compactMap { Int($0) }
            if partes.count == 2 { aplicarHidutil(vendor: partes[0], produto: partes[1], json: TecladoPC.semMapeamento) }
        }
        aplicados.removeAll()
    }

    private func varrer() {
        for (vendor, produto) in tecladosExternos() {
            if jaRemapeadoPeloSistema(vendor: vendor, produto: produto) { continue }
            aplicados.insert("\(vendor)-\(produto)")
            if !mapeamentoCompleto(vendor: vendor, produto: produto) {
                aplicarHidutil(vendor: vendor, produto: produto, json: TecladoPC.mapeamento)
            }
        }
    }

    private func mapeamentoCompleto(vendor: Int, produto: Int) -> Bool {
        let filtro = "{\"VendorID\":\(vendor),\"ProductID\":\(produto)}"
        let saida = Shell.rodar("/usr/bin/hidutil", ["property", "--matching", filtro, "--get", "UserKeyMapping"])
        return saida.contains("HIDKeyboardModifierMappingDst") && !saida.contains("(null)")
    }

    private func tecladosExternos() -> [(Int, Int)] {
        let saida = Shell.rodar("/usr/bin/hidutil", ["list", "--matching", "{\"PrimaryUsagePage\":1,\"PrimaryUsage\":6}"])
        var encontrados: [(Int, Int)] = []
        var secaoServicos = false
        for linha in saida.split(separator: "\n") {
            if linha.hasPrefix("Services:") { secaoServicos = true; continue }
            if linha.hasPrefix("Devices:") { secaoServicos = false; continue }
            guard secaoServicos else { continue }
            let colunas = linha.split(separator: " ", omittingEmptySubsequences: true)
            guard colunas.count >= 2, colunas[0].hasPrefix("0x"), colunas[1].hasPrefix("0x"),
                  let vendor = Int(colunas[0].dropFirst(2), radix: 16),
                  let produto = Int(colunas[1].dropFirst(2), radix: 16) else { continue }
            if vendor == TecladoPC.fabricanteApple { continue }
            if !encontrados.contains(where: { $0.0 == vendor && $0.1 == produto }) { encontrados.append((vendor, produto)) }
        }
        return encontrados
    }

    private func jaRemapeadoPeloSistema(vendor: Int, produto: Int) -> Bool {
        let chave = "com.apple.keyboard.modifiermapping.\(vendor)-\(produto)-0" as CFString
        let valor = CFPreferencesCopyValue(chave, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        return (valor as? [Any])?.isEmpty == false
    }

    private func aplicarHidutil(vendor: Int, produto: Int, json: String) {
        let filtro = "{\"VendorID\":\(vendor),\"ProductID\":\(produto)}"
        Shell.rodar("/usr/bin/hidutil", ["property", "--matching", filtro, "--set", json])
    }
}

enum LayoutABNT2 {
    static func selecionar() -> Bool {
        let filtro = [kTISPropertyInputSourceID as String: "com.apple.keylayout.Brazilian-ABNT2"] as CFDictionary
        guard let lista = TISCreateInputSourceList(filtro, true)?.takeRetainedValue() as? [TISInputSource],
              let fonte = lista.first else { return false }
        TISEnableInputSource(fonte)
        return TISSelectInputSource(fonte) == noErr
    }
}
