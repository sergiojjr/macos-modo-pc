# Modo PC

Veio do Windows e sente falta das coisas do seu jeito? O Modo PC deixa o Mac mais parecido com o que você já está acostumado: Alt+Tab, clicar no Dock pra minimizar, rolar a página com o botão do meio e teclado de PC funcionando direito.

Ele fica quietinho na barra de menus, roda em Mac Intel e Apple Silicon (macOS 12 ou mais novo) e não precisa de mais nada instalado.

Clicou no ícone (os quatro quadradinhos)? Aparece a lista de funções, e cada uma liga e desliga separadamente. O que você escolher fica salvo.

## O que ele faz

### Clicar no Dock minimiza e restaura
Igual à barra de tarefas do Windows.
- Clicou no ícone de um app que está na frente? Ele **minimiza**.
- Clicou de novo? Ele **volta** pra tela.

O clique passa normal pro Dock e o Modo PC age logo depois que você solta o botão. Tem um intervalinho de 0,6 s entre uma ação e outra, pra clique duplo não virar um vai e vem.

### Alt+Tab do jeito da Apple
Um painel com vidro embaçado, ícones grandes, um destaque que desliza e o nome do app embaixo, quase igual ao Cmd+Tab.
- **Alt+Tab** abre o painel já no app anterior. Cada Tab avança, e dá pra segurar pra ir passando.
- **Alt+Shift+Tab** volta.
- **Setas** navegam, **Enter** confirma e **Esc** cancela.
- **Soltou o Alt, escolheu.** Não precisa apertar Enter.
- A ordem segue o que você usou por último, como no Cmd+Tab.
- Se o app escolhido estiver com tudo minimizado ou escondido, ele volta pra frente. Se o app demorar pra responder, o Modo PC insiste por uns 0,8 s e, no último caso, reabre o app como se você tivesse clicado no Dock.

No teclado de PC, o Alt é o Option do Mac.

### Rolagem automática com o botão do meio
Segura o botão do meio (aquele clique na rodinha) e mexe o mouse pra cima ou pra baixo. A página rola pro lado que você mexeu, e quanto mais longe do ponto onde clicou, mais rápido ela anda. Soltou, parou.

Um clique rápido na rodinha, sem mexer o mouse, continua funcionando normal (tipo abrir link em nova aba).

### Teclado de PC: Ctrl ↔ Cmd e Win ↔ Ctrl
Deixa o teclado de PC com o comportamento do Windows:
- **Ctrl** vira **Cmd (⌘)**, então Ctrl+C, Ctrl+V e Ctrl+Z funcionam como você espera.
- **Tecla Windows** vira **Control (⌃)**.
- O Alt continua sendo o Option.

Isso só vale pra teclado que **não é da Apple**. Se você plugar outro teclado depois, ele é ajustado sozinho, e ao desligar a função tudo volta ao normal. Teclado que você já remapeou em Ajustes do Sistema → Teclado → Teclas de Modificação é deixado em paz, pra uma troca não desfazer a outra.

### Layout ABNT2
O item **Usar layout de teclado ABNT2** ativa e seleciona o "Português – Brasil (ABNT2)": o ç no lugar certo e as teclas de acento como no teclado brasileiro.

### Atalhos do Windows
Traz pro Mac aqueles atalhos de edição que o dedo já conhece. Vem **desligada** por padrão: ligue no menu se você usa teclado de PC.

| No Windows | O que acontece no Mac |
| --- | --- |
| **Ctrl+C** / **Ctrl+V** / **Ctrl+Z** | Copia, cola e desfaz (vêm da troca Ctrl ↔ Cmd, explicada em "Teclado de PC") |
| **Home** / **End** | Vai pro começo / fim da linha |
| **Ctrl+Home** / **Ctrl+End** | Vai pro começo / fim do documento |
| **Ctrl+← / →** | Pula de palavra em palavra |
| **Ctrl+Backspace** / **Ctrl+Delete** | Apaga a palavra anterior / seguinte |
| **Alt+F4** | Fecha a janela (Cmd+W) |

O Shift continua funcionando junto, então Shift+Home e Ctrl+Shift+← selecionam do jeito que você espera.

Ela trabalha em cima da troca Ctrl ↔ Cmd, então só faz sentido com ela ligada. É essa mesma troca que faz o Ctrl+C, o Ctrl+V e o Ctrl+Z funcionarem, mesmo com a função de atalhos desligada. Detalhe importante: por causa dessa troca, o Cmd+← e o Cmd+→ de um teclado da Apple também viram "pular palavra". Se você alterna entre teclado de PC e de Mac, deixe essa função desligada.

### Esconder o selo de atualização
Some com aquela bolinha vermelha de atualização do ícone de Ajustes do Sistema. Ajuda quando o seu Mac não consegue instalar o macOS mais novo e o aviso fica te cutucando pra sempre. Ele confere ao abrir e a cada 2 minutos.

### Abrir ao iniciar sessão
Faz o Modo PC abrir sozinho quando você liga o Mac. Ele cria um arquivo em `~/Library/LaunchAgents/com.modopc.app.plist` apontando pra onde o app estiver instalado. Desmarcou? O arquivo é apagado.

## Como instalar

1. Arrasta o `Modo PC.app` pra pasta Aplicativos.
2. Na primeira vez, clica com o botão direito no app, escolhe **Abrir** e confirma. O macOS reclama de "desenvolvedor não identificado" porque o app é assinado só localmente. É normal.
3. Libera as permissões em **Ajustes do Sistema → Privacidade e Segurança**:
   - **Acessibilidade**, pra ele mexer nas janelas e capturar os atalhos.
   - **Monitoramento de Entrada**, pra ele enxergar teclas e cliques.

   O menu do app tem atalhos pras duas telas.
4. Se quiser, marca **Abrir ao iniciar sessão**.

Usa Hammerspoon com algo parecido (Alt+Tab, clique no Dock)? Fecha ele antes. Os dois brigariam pelos mesmos atalhos.

## Como compilar

Precisa do Xcode ou das Command Line Tools.

```sh
./build.sh
```

Isso gera o `build/Modo PC.app` como binário universal (Intel e Apple Silicon). A assinatura usa um requisito fixo de identidade (`com.modopc.app`), então as permissões que você já liberou continuam valendo depois de recompilar.

## Mapa do código

| Arquivo | O que tem |
| --- | --- |
| `Sources/main.swift` | Menu da barra, preferências, permissões e início com o sistema |
| `Sources/Base.swift` | Base das funções, filtro de eventos e utilidades de Acessibilidade |
| `Sources/DockClick.swift` | Minimizar e restaurar pelo Dock |
| `Sources/AltTab.swift` | Painel e lógica do Alt+Tab |
| `Sources/AutoScroll.swift` | Rolagem automática |
| `Sources/TecladoPC.swift` | Remapeamento de teclado e layout ABNT2 |
| `Sources/AtalhosWindows.swift` | Atalhos de edição do Windows (Home/End, Ctrl+setas, Alt+F4…) |
| `Sources/UpdateBadge.swift` | Selo de atualização |
