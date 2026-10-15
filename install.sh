#!/usr/bin/env bash
# ==============================================================================
# Plataforma Ridel — Instalador Universal da CLI (Host)
# ==============================================================================
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/p-ridel/p-ridel/main/install.sh | bash
# ==============================================================================

set -e

# Estilos e Cores ANSI
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✔${NC} $1"; }
warn()    { echo -e "${YELLOW}▲${NC} $1"; }
error()   { echo -e "${RED}✖${NC} $1"; }

echo ""
echo -e "${BOLD}${CYAN}================================================================${NC}"
echo -e "${BOLD}      Plataforma Ridel — Instalador da CLI no Host             ${NC}"
echo -e "${BOLD}${CYAN}================================================================${NC}"
echo ""

# 1. Definir diretório de instalação
if [ "$(id -u)" -eq 0 ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

mkdir -p "$INSTALL_DIR"
TARGET_FILE="$INSTALL_DIR/ridel"

# 2. Baixar o executável oficial da CLI
RIDEL_SOURCE_URL="${RIDEL_RAW_URL:-https://raw.githubusercontent.com/p-ridel/p-ridel/main/ridel}"

info "Baixando utilitário CLI 'ridel'..."
TMP_FILE="$(mktemp)"

if ! curl -fsSL "$RIDEL_SOURCE_URL" -o "$TMP_FILE"; then
  rm -f "$TMP_FILE"
  error "Falha ao baixar a CLI de '$RIDEL_SOURCE_URL'."
  info "Verifique sua conexão com a internet ou o endereço informado."
  exit 1
fi

mv "$TMP_FILE" "$TARGET_FILE"
chmod +x "$TARGET_FILE"
success "CLI 'ridel' instalada com sucesso em: ${BOLD}$TARGET_FILE${NC}"

# 3. Verificar se o diretório de instalação está no PATH
path_configured=0
case ":$PATH:" in
  *":$INSTALL_DIR:"*) path_configured=1 ;;
  *) path_configured=0 ;;
esac

if [ "$path_configured" -eq 0 ]; then
  info "Configurando $INSTALL_DIR na variável PATH do seu shell..."
  
  export_line="export PATH=\"$INSTALL_DIR:\$PATH\""
  
  # Adiciona ao .bashrc se existir ou como default
  if [ -f "$HOME/.bashrc" ] || [ ! -f "$HOME/.zshrc" ]; then
    if ! grep -qF "$INSTALL_DIR" "$HOME/.bashrc" 2>/dev/null; then
      echo "" >> "$HOME/.bashrc"
      echo "# Ridel CLI" >> "$HOME/.bashrc"
      echo "$export_line" >> "$HOME/.bashrc"
      success "Adicionado ao $HOME/.bashrc"
    fi
  fi

  # Adiciona ao .zshrc se existir
  if [ -f "$HOME/.zshrc" ]; then
    if ! grep -qF "$INSTALL_DIR" "$HOME/.zshrc" 2>/dev/null; then
      echo "" >> "$HOME/.zshrc"
      echo "# Ridel CLI" >> "$HOME/.zshrc"
      echo "$export_line" >> "$HOME/.zshrc"
      success "Adicionado ao $HOME/.zshrc"
    fi
  fi

  warn "Para ativar a CLI na sessão atual do terminal, execute:"
  echo -e "   ${BOLD}$export_line${NC}"
fi

# 4. Verificar se o Docker está instalado no host
echo ""
if command -v docker >/dev/null 2>&1; then
  docker_version="$(docker --version 2>/dev/null || echo 'Docker detectado')"
  success "Ambiente Docker verificado: $docker_version"
else
  warn "Docker não foi detectado no sistema."
  info "A Plataforma Ridel necessita do Docker para executar os contêineres."
  info "Instale o Docker em https://docs.docker.com/engine/install/ para iniciar a plataforma."
fi

# 5. Instruções finais
echo ""
echo -e "${BOLD}${GREEN}Pronto para começar!${NC}"
echo -e "Experimente os comandos principais:"
echo -e "  ${CYAN}ridel status${NC}           Verificar o status da plataforma"
echo -e "  ${CYAN}ridel tenant create <app>${NC} Criar uma nova aplicação"
echo -e "  ${CYAN}ridel check <app>${NC}      Validar integridade declarativa"
echo -e "  ${CYAN}ridel update${NC}           Atualizar para a última versão oficial"
echo -e "  ${CYAN}ridel help${NC}             Exibir todos os comandos disponíveis"
echo ""
