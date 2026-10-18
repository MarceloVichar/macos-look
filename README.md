# macOS Look para Ubuntu

Transforma o Ubuntu 26.04 (GNOME 50) em uma experiência visual e de uso próxima do macOS com **um único script**, sem intervenção manual.

## Uso rápido

```bash
cd ~/macos-look
./setup-macos-look.sh            # modo escuro (padrão)
./setup-macos-look.sh --light    # modo claro
./setup-macos-look.sh --firefox  # também aplica tema estilo Safari no Firefox
./setup-macos-look.sh --revert   # volta às configurações originais
```

Depois da **primeira** execução, faça **logout e login** uma vez. No Wayland a extensão que aplica o tema da barra superior só é carregada no login.

Para levar a outra máquina, basta copiar `setup-macos-look.sh` e rodá-lo como usuário normal (não use `sudo` na frente). Ele pede a senha só para instalar os pacotes do apt, no terminal ou, se não houver terminal, pela janela gráfica do GNOME.

## O que o script faz, passo a passo

| # | Etapa | Detalhe |
|---|-------|---------|
| 1 | Backup | `dconf dump /` → `~/.local/share/macos-look/dconf-backup.ini` (somente na 1ª execução, preservando o estado original) |
| 2 | Dependências (apt) | `sassc libglib2.0-dev-bin libxml2-utils` (compilar o tema), `gnome-shell-extension-user-theme` (tema da barra superior), `fonts-inter` (substituta livre da SF Pro) |
| 3 | Tema GTK + Shell | [WhiteSur-gtk-theme](https://github.com/vinceliuice/WhiteSur-gtk-theme) tag `2026-09-10`, compilado com `-c light -c dark -o normal -l --shell -i apple` → `~/.themes`, apps GTK4/libadwaita via `~/.config/gtk-4.0`, logo da Apple no canto superior esquerdo |
| 4 | Ícones | [WhiteSur-icon-theme](https://github.com/vinceliuice/WhiteSur-icon-theme) tag `2026-09-10` → `~/.local/share/icons` |
| 5 | Cursor | [WhiteSur-cursors](https://github.com/vinceliuice/WhiteSur-cursors) commit `e190baf` → `~/.local/share/icons` (+ link em `~/.icons`) |
| 6 | Papel de parede | WhiteSur claro/escuro 1080p → `~/.local/share/backgrounds/macos-look`, troca sozinho junto com o tema |
| 7 | gsettings | ver tabela abaixo |
| 8 | User Themes | ativa a extensão e aponta o tema do Shell para WhiteSur |

As versões ficam fixadas no topo do script (`GTK_REF`, `ICON_REF`, `CURSOR_REF`, `WALL_REF`), o que garante o mesmo resultado em qualquer máquina. Para atualizar, troque essas variáveis.

### Ajustes aplicados

**Janelas e visual**
- Botões **fechar / minimizar / maximizar à esquerda** (`close,minimize,maximize:`)
- Novas janelas abrem centralizadas
- Cor de destaque azul, fonte **Inter 10** na interface e **Inter Bold** nos títulos, suavização em tons de cinza (como no macOS)
- Relógio com dia da semana e data; hot corner desativado

**Dock** (o Ubuntu Dock que já vem no sistema, sem extensão nova)
- Embaixo, centralizado, sem ocupar a altura toda, ícones de 48 px
- Fundo translúcido (35%), um ponto indicando app aberto, Lixeira no Dock
- Esconde quando uma janela encosta nele (intellihide)
- Clique num ícone foca o app; se houver várias janelas, mostra as prévias

**Área de trabalho**: ícones no canto superior direito, sem o atalho "Pasta pessoal".

**Atalhos** (Super = Command)

| macOS | Aqui | Ação |
|---|---|---|
| ⌘ Espaço | `Super+Espaço` | Busca/visão geral (equivalente ao Spotlight) |
| ⌘ Q | `Super+Q` | Fechar janela (Alt+F4 continua funcionando) |
| ⌘ ⇧ 3 | `Shift+Super+3` | Print da tela inteira |
| ⌘ ⇧ 4 / 5 | `Shift+Super+4` / `5` | Ferramenta de captura (área/janela/vídeo) |
| ⌘ Tab | `Super+Tab` | Alternar apps (padrão do GNOME) |
| ⌘ ` | ``Super+` `` (tecla acima do Tab) | Alternar janelas do mesmo app (padrão do GNOME) |
| — | `Shift+Super+Espaço` | Trocar layout de teclado (antes era Super+Espaço) |

**Touchpad**: rolagem natural e toque para clicar.

## Desempenho

Nada foi adicionado que rode em segundo plano:
- **Sem** Blur My Shell ou blur em tempo real; a translucidez do painel e do Dock é uma cor com alfa, de custo praticamente zero
- **Sem** remapeadores de teclado em Python (Toshy/Kinto); os atalhos são keybindings nativos do GNOME
- **Sem** dock extra (Plank etc.); a configuração é feita no Ubuntu Dock que já existia
- A única extensão nova, User Themes, só carrega um arquivo CSS
- Wallpaper em 1080p, que usa ~4× menos memória de vídeo que 4K (troque `WALL_RES="4k"` se o monitor for 4K)

## Limitações conhecidas

- **Apps Snap** (Firefox, Thunderbird, Loja) usam o próprio tema embutido e não leem `~/.themes`. As barras de título e o restante do sistema seguem o WhiteSur, mas o conteúdo pode ficar com visual Yaru. O `--firefox` aplica o CSS estilo Safari dentro do Firefox (precisa ter aberto o Firefox ao menos uma vez antes).
- **Apps libadwaita (GTK4)** são temados por `~/.config/gtk-4.0`. Ao trocar claro/escuro pelas Configurações, rode o script de novo com `--light`/`--dark` ou use o app **GTK4 Theme Switcher** (instalado pelo WhiteSur), para que eles acompanhem.
- **Tela de login (GDM)** não é alterada de propósito, porque mexer nela exige root e pode quebrar o login após atualizações do Ubuntu. Se quiser mesmo assim: na pasta do WhiteSur, `sudo ./tweaks.sh -g`.
- **Atalhos de edição** (Ctrl+C/V) continuam com Ctrl. Trocar para Super exige um daemon remapeador, o que vai contra a regra de não pesar.
- O CSS GTK4 do WhiteSur usa margem negativa nas abas, e o libadwaita reclama no log ("tabboxchild reported min width -6"). O script corrige isso depois de instalar o tema.
- O tema do Shell do WhiteSur declara suporte oficial até o GNOME 48. No GNOME 50 ele funciona, mas algum detalhe novo do Shell pode ficar com o estilo padrão.

## Desfazer

```bash
./setup-macos-look.sh --revert   # restaura todas as configurações do backup
# opcional: apagar os arquivos instalados
rm -rf ~/.themes/WhiteSur-* ~/.local/share/icons/WhiteSur* ~/.icons/WhiteSur-cursors \
       ~/.local/share/backgrounds/macos-look ~/.local/share/applications/org.gnome.GTK4ThemeSwitcher.desktop
```

Os pacotes do apt podem ser removidos com `sudo apt remove sassc gnome-shell-extension-user-theme fonts-inter` (os outros são utilitários inofensivos).
