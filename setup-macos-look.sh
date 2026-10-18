#!/usr/bin/env bash
# =============================================================================
#  setup-macos-look.sh — deixa o Ubuntu (GNOME) com aparência/experiência macOS
#
#  Testado em: Ubuntu 26.04 LTS, GNOME Shell 50, Wayland.
#  Uso:
#     ./setup-macos-look.sh              # instala/aplica tudo (modo escuro)
#     ./setup-macos-look.sh --light      # idem, em modo claro
#     ./setup-macos-look.sh --firefox    # também aplica o tema WhiteSur no Firefox
#     ./setup-macos-look.sh --revert     # restaura o backup das configurações
#
#  Idempotente: pode ser executado várias vezes. Não instala nada que rode em
#  segundo plano (sem blur dinâmico, sem daemons): só temas, fontes e gsettings.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------- versões fixas
# Fixamos versões para que o resultado seja sempre o mesmo.
GTK_REF="2026-09-10"                                   # WhiteSur-gtk-theme (tag)
ICON_REF="2026-09-10"                                  # WhiteSur-icon-theme (tag)
CURSOR_REF="e190baf618ed95ee217d2fd45589bd309b37672b"  # WhiteSur-cursors (commit)
WALL_REF="5c1d7ca20b8de0a7efe443792c19e49277262e02"    # WhiteSur-wallpapers (commit)
WALL_NAME="WhiteSur"                                   # usa <nome>-light.jpg / <nome>-dark.jpg
WALL_RES="1080p"                                       # 1080p ou 4k (1080p = menos RAM/VRAM)

APT_PKGS=(sassc libglib2.0-dev-bin libxml2-utils gnome-shell-extension-user-theme fonts-inter)

# ------------------------------------------------------------------- argumentos
MODE="dark"; FIREFOX=0; REVERT=0
for arg in "$@"; do
  case "$arg" in
    --light)   MODE="light" ;;
    --dark)    MODE="dark" ;;
    --firefox) FIREFOX=1 ;;
    --revert)  REVERT=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

STATE_DIR="$HOME/.local/share/macos-look"
BACKUP="$STATE_DIR/dconf-backup.ini"
mkdir -p "$STATE_DIR"

log()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }

[[ $EUID -eq 0 ]] && { echo "Rode como usuário normal (sem sudo); o script pede sudo quando precisar." >&2; exit 1; }

# ---------------------------------------------------------------------- revert
if (( REVERT )); then
  [[ -f "$BACKUP" ]] || { echo "Backup não encontrado em $BACKUP" >&2; exit 1; }
  log "Restaurando configurações do backup"
  dconf reset -f /org/gnome/desktop/interface/
  dconf reset -f /org/gnome/desktop/wm/
  dconf reset -f /org/gnome/shell/
  dconf reset -f /org/gnome/mutter/
  dconf reset -f /org/gnome/desktop/background/
  dconf reset -f /org/gnome/desktop/screensaver/
  dconf reset -f /org/gnome/desktop/peripherals/touchpad/
  dconf load / < "$BACKUP"
  ( cd "$HOME/.config/gtk-4.0" 2>/dev/null && rm -rf gtk.css gtk-dark.css gtk-Dark.css gtk-Light.css assets windows-assets )
  echo "Feito. Temas continuam em ~/.themes e ~/.local/share/icons (apague se quiser). Faça logout/login."
  exit 0
fi

# ---------------------------------------------------------------------- backup
if [[ ! -f "$BACKUP" ]]; then
  log "Fazendo backup das configurações atuais em $BACKUP"
  dconf dump / > "$BACKUP"
fi

# ----------------------------------------------------------------- dependências
missing=()
for p in "${APT_PKGS[@]}"; do
  dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || missing+=("$p")
done
if (( ${#missing[@]} )); then
  log "Instalando dependências via apt: ${missing[*]}"
  if sudo -n true 2>/dev/null || [[ -t 0 ]]; then
    sudo apt-get update -qq && sudo apt-get install -y "${missing[@]}"
  else  # sem terminal (ex.: atalho/IDE): janela gráfica de senha
    pkexec env DEBIAN_FRONTEND=noninteractive sh -c 'apt-get update -qq && apt-get install -y "$@"' _ "${missing[@]}"
  fi
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fetch() {  # fetch <repo> <ref> -> extrai em $WORK e imprime o diretório
  local repo="$1" ref="$2" dir="$WORK/$1"
  mkdir -p "$dir"
  curl -fsSL "https://github.com/vinceliuice/$repo/archive/$ref.tar.gz" | tar xz -C "$dir" --strip-components=1
  echo "$dir"
}

if [[ $MODE == dark ]]; then
  GTK_THEME="WhiteSur-Dark"; ICON_THEME="WhiteSur-dark"; SCHEME="prefer-dark"
else
  GTK_THEME="WhiteSur-Light"; ICON_THEME="WhiteSur-light"; SCHEME="default"
fi

# ------------------------------------------------------------ tema GTK + Shell
log "Compilando e instalando tema WhiteSur GTK/Shell ($GTK_REF)"
src="$(fetch WhiteSur-gtk-theme "$GTK_REF")"
# -c light -c dark : instala as duas variantes (permite trocar depois sem reinstalar)
# -o normal        : painel translúcido estático (sem blur em tempo real)
# -l               : aplica nos apps libadwaita/GTK4 (~/.config/gtk-4.0)
# --shell -i apple : ícone da Apple no canto superior esquerdo
( cd "$src" && ./install.sh -c light -c dark -o normal -l --shell -i apple )
# -l instala gtk-Light.css e gtk-Dark.css e aponta gtk.css para o escuro;
# ajusta o link para o modo escolhido
G4="$HOME/.config/gtk-4.0"
[[ $MODE == light && -f "$G4/gtk-Light.css" ]] && ln -sfn "$G4/gtk-Light.css" "$G4/gtk.css"
# Correção: margem negativa nas abas (libadwaita rejeita e o Ptyxis/terminal
# registra "tabboxchild reported min width -6" no log a cada segundo)
for css in "$G4"/gtk-{Dark,Light}.css "$HOME"/.themes/WhiteSur-*/gtk-4.0/gtk*.css; do
  [[ -f $css ]] && perl -0pi -e 's/(tabbar scrolledwindow:not\(\.pinned\) tabbox > tabboxchild \{\s*margin:) 0 -3px;/$1 0;/g' "$css"
done

if (( FIREFOX )); then
  log "Aplicando tema WhiteSur no Firefox"
  pkill -x firefox 2>/dev/null && sleep 2 || true
  ( cd "$src" && ./tweaks.sh -f ) || warn "Falha no tema do Firefox (abra o Firefox uma vez e rode de novo)."
fi

# ------------------------------------------------------------------- ícones
log "Instalando ícones WhiteSur ($ICON_REF)"
src="$(fetch WhiteSur-icon-theme "$ICON_REF")"
( cd "$src" && ./install.sh -t default ) >/dev/null

# ------------------------------------------------------------------- cursor
log "Instalando cursor WhiteSur"
src="$(fetch WhiteSur-cursors "$CURSOR_REF")"
mkdir -p "$HOME/.local/share/icons" "$HOME/.icons"
rm -rf "$HOME/.local/share/icons/WhiteSur-cursors"
cp -pr "$src/dist" "$HOME/.local/share/icons/WhiteSur-cursors"
ln -sfn "$HOME/.local/share/icons/WhiteSur-cursors" "$HOME/.icons/WhiteSur-cursors"  # apps XWayland/legados

# ----------------------------------------------------------------- wallpaper
log "Baixando papel de parede ($WALL_NAME claro/escuro, troca automática com o tema)"
WALL_DIR="$HOME/.local/share/backgrounds/macos-look"
mkdir -p "$WALL_DIR"
for v in light dark; do
  f="$WALL_DIR/$WALL_NAME-$v.jpg"
  [[ -s $f ]] || curl -fsSL -o "$f" \
    "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/$WALL_REF/$WALL_RES/$WALL_NAME-$v.jpg"
done

# ------------------------------------------------------------------ gsettings
log "Aplicando configurações do GNOME"
gs() { gsettings set "$@" 2>/dev/null || warn "não aplicado: $*"; }

# Aparência
gs org.gnome.desktop.interface gtk-theme        "$GTK_THEME"
gs org.gnome.desktop.interface icon-theme       "$ICON_THEME"
gs org.gnome.desktop.interface cursor-theme     "WhiteSur-cursors"
gs org.gnome.desktop.interface cursor-size      24
gs org.gnome.desktop.interface color-scheme     "$SCHEME"
gs org.gnome.desktop.interface accent-color     "blue"
gs org.gnome.desktop.wm.preferences theme       "$GTK_THEME"

# Fontes (Inter é o equivalente livre mais próximo da SF Pro)
gs org.gnome.desktop.interface font-name          "Inter 10"
gs org.gnome.desktop.interface document-font-name "Inter 11"
gs org.gnome.desktop.wm.preferences titlebar-font "Inter Bold 10"
gs org.gnome.desktop.interface font-antialiasing  "grayscale"
gs org.gnome.desktop.interface font-hinting       "slight"

# Botões das janelas à esquerda, ordem do macOS (fechar, minimizar, maximizar)
gs org.gnome.desktop.wm.preferences button-layout "close,minimize,maximize:"
gs org.gnome.mutter center-new-windows true

# Barra superior: dia da semana + data como no macOS
gs org.gnome.desktop.interface clock-show-weekday true
gs org.gnome.desktop.interface clock-show-date    true
gs org.gnome.desktop.interface enable-hot-corners false

# Papel de parede (claro/escuro automático)
gs org.gnome.desktop.background picture-uri      "file://$WALL_DIR/$WALL_NAME-light.jpg"
gs org.gnome.desktop.background picture-uri-dark "file://$WALL_DIR/$WALL_NAME-dark.jpg"
gs org.gnome.desktop.background picture-options  "zoom"
gs org.gnome.desktop.screensaver picture-uri     "file://$WALL_DIR/$WALL_NAME-dark.jpg"

# Dock (Ubuntu Dock já vem instalado — nenhum processo extra)
D=org.gnome.shell.extensions.dash-to-dock
gs $D dock-position         "BOTTOM"
gs $D extend-height         false
gs $D dock-fixed            false
gs $D autohide              true
gs $D intellihide           true
gs $D intellihide-mode      "FOCUS_APPLICATION_WINDOWS"
gs $D dash-max-icon-size    48
gs $D show-apps-at-top      false
gs $D show-show-apps-button true
gs $D show-trash            true
gs $D show-mounts           false
gs $D click-action          "focus-or-previews"
gs $D scroll-action         "do-nothing"
gs $D running-indicator-style "DOT"
gs $D apply-custom-theme    false
gs $D custom-theme-shrink   true
gs $D transparency-mode     "FIXED"
gs $D background-opacity    0.35
gs $D hot-keys              false   # libera Super+1..9 (mantém atalhos padrão do GNOME)

# Ícones da área de trabalho no canto superior direito, sem "Pasta pessoal"
gs org.gnome.shell.extensions.ding show-home    false
gs org.gnome.shell.extensions.ding show-trash   false
gs org.gnome.shell.extensions.ding start-corner "top-right"

# Atalhos estilo macOS (Super = Command)
gs org.gnome.shell.keybindings toggle-overview     "['<Super>space']"          # "Spotlight"
gs org.gnome.desktop.wm.keybindings switch-input-source          "['<Shift><Super>space', 'XF86Keyboard']"
gs org.gnome.desktop.wm.keybindings switch-input-source-backward "[]"
gs org.gnome.desktop.wm.keybindings close          "['<Alt>F4', '<Super>q']"   # Cmd+Q
gs org.gnome.shell.keybindings screenshot          "['<Shift><Super>3', '<Shift>Print']"  # Cmd+Shift+3
gs org.gnome.shell.keybindings show-screenshot-ui  "['Print', '<Shift><Super>4', '<Shift><Super>5']"
gs org.gnome.shell.keybindings screenshot-window   "['<Alt>Print']"

# Touchpad: rolagem natural e toque para clicar (padrão do Mac)
gs org.gnome.desktop.peripherals.touchpad natural-scroll true
gs org.gnome.desktop.peripherals.touchpad tap-to-click   true

# Favoritos do Dock: remove o instalador do Ubuntu, se presente
fav="$(gsettings get org.gnome.shell favorite-apps)"
fav="${fav//\'ubuntu-desktop-bootstrap_ubuntu-desktop-bootstrap.desktop\', /}"
gs org.gnome.shell favorite-apps "$fav"

# ------------------------------------------------- extensão User Themes (Shell)
log "Ativando tema da barra superior (extensão User Themes)"
UT="user-theme@gnome-shell-extensions.gcampax.github.com"
enabled="$(gsettings get org.gnome.shell enabled-extensions)"
if [[ $enabled != *"$UT"* ]]; then
  if [[ $enabled == "@as []" || $enabled == "[]" ]]; then enabled="['$UT']"
  else enabled="${enabled%]}, '$UT']"; fi
  gs org.gnome.shell enabled-extensions "$enabled"
fi
gnome-extensions enable "$UT" 2>/dev/null || true
gs org.gnome.shell.extensions.user-theme name "$GTK_THEME"

# Flatpak: deixa apps Flatpak lerem o tema (se Flatpak estiver instalado)
if command -v flatpak >/dev/null; then
  flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem="$HOME/.themes:ro" --filesystem="$HOME/.local/share/icons:ro" || true
fi

log "Pronto!"
echo "Faça logout e login uma vez para a barra superior (tema do Shell) carregar por completo."
echo "Para desfazer: $0 --revert"
