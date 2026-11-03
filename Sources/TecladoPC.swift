import Cocoa
import IOKit.hid
import Carbon.HIToolbox

final class TecladoPC: Feature {
    private var gerente: IOHIDManager?
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
        let g = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let filtro: [String: Int] = [kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
                                     kIOHIDPrimaryUsageKey: kHIDUsage_GD_Keyboard]
        IOHIDManagerSetDeviceMatching(g, filtro as CFDictionary)
        let contexto = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(g, { contexto, _, _, _ in
            guard let contexto = contexto else { return }
            let eu = Unmanaged<TecladoPC>.fromOpaque(contexto).takeUnretainedValue()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { eu.varrer() }
        }, contexto)
        IOHIDManagerScheduleWithRunLoop(g, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(g, IOOptionBits(kIOHIDOptionsTypeNone))
        gerente = g
        varrer()
        return true
    }

    override func desativar() {
        for id in aplicados {
            let partes = id.split(separator: "-").compactMap { Int($0) }
            if partes.count == 2 { aplicarHidutil(vendor: partes[0], produto: partes[1], json: TecladoPC.semMapeamento) }
        }
        aplicados.removeAll()
        if let g = gerente {
            IOHIDManagerUnscheduleFromRunLoop(g, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(g, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        gerente = nil
    }

    private func varrer() {
        guard ativo, let g = gerente, let conjunto = IOHIDManagerCopyDevices(g) as? Set<IOHIDDevice> else { return }
        for dispositivo in conjunto {
            guard let vendor = IOHIDDeviceGetProperty(dispositivo, kIOHIDVendorIDKey as CFString) as? Int,
                  let produto = IOHIDDeviceGetProperty(dispositivo, kIOHIDProductIDKey as CFString) as? Int else { continue }
            if vendor == TecladoPC.fabricanteApple { continue }
            let id = "\(vendor)-\(produto)"
            if aplicados.contains(id) || jaRemapeadoPeloSistema(vendor: vendor, produto: produto) { continue }
            aplicarHidutil(vendor: vendor, produto: produto, json: TecladoPC.mapeamento)
            aplicados.insert(id)
        }
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
