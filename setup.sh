#!/bin/zsh

set -e

###############################################
#   Options
###############################################

# OS detection — must happen before anything uses $OS.
OS="Linux"
if [[ "$(uname)" == "Darwin" ]]; then
  OS="MacOS"
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
  OS="Linux"
else
  echo "Unsupported OS. Exit."
  exit 1
fi

# Basic.
DEFAULT_SHELL=/usr/bin/zsh
NVIM_CONF_LINK=~/.config/nvim
TMUX_CONF_LINK=~/.tmux.conf
NEOVIDE_CONF_LINK=~/.config/neovide/config.toml
NVIM_INSTALL_PATH="$HOME/.local/nvim/"
DEFAULT_ENV_FILE_PATH=~/.zprofile
INSTALL_DEPENDENCIES="git curl " # Everything relies on them...
INSTALL_DEPENDENCIES+="cmake make gcc " # required by luasnip, ray-x and treesitter.
INSTALL_DEPENDENCIES+="tmux lazygit zoxide " # handy cmd tools.
INSTALL_DEPENDENCIES+="fzf ripgrep fd " # builtin searches.
INSTALL_DEPENDENCIES+="node " # required by copilot. npm comes with node (not a separate brew formula).
INSTALL_DEPENDENCIES+="unzip zip lua@5.4 luarocks "
INSTALL_DEPENDENCIES+="sqlite " # required by bookmarks.nvim
INSTALL_DEPENDENCIES+="gh " # required by Snacks.nvim/gh
INSTALL_FONT_PATH=""
CONTINUE_ON_ERROR=true
INSTALL_NVIM_FROM_SOURCE=0
DEFAULT_MASON_PATH="$HOME/.local/share/nvim/mason/bin"

# Generated options.
CURRENT_ABS=$(realpath "$0")
CURRENT_BASEDIR=$(dirname "$CURRENT_ABS")
DEFAULT_SHELL_RC_FILENAME=".$(basename "$DEFAULT_SHELL")rc"
DEFAULT_SHELL_RC="$HOME/$DEFAULT_SHELL_RC_FILENAME" # Ensure absolute path
SNIPPET_LINK="$HOME/.config/nvim/snip" # Define SNIPPET_LINK to prevent undefined variable

if [[ "$OS" == "MacOS" ]]; then
  INSTALL_FONT_PATH="/Library/Fonts/"
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES pngpaste"
else
  INSTALL_FONT_PATH="$HOME/.local/share/fonts/"
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES xsel"
fi

if [ "$INSTALL_NVIM_FROM_SOURCE" -ne 0 ]; then
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES gcc cmake"
else
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES neovim"
fi

###############################################
#   Helper functions
###############################################

# Check if a command is already installed, skip if so.
check_installed() {
  command -v "$1" &>/dev/null
}

# Safely source a file (no error if it doesn't exist).
safe_source() {
  if [[ -f "$1" ]]; then
    source "$1"
  fi
}

###############################################
#   Shell RC setup
###############################################
echo "Writing to shell rc: ${DEFAULT_SHELL_RC}"

# Idempotent: only add source line if not already present.
if ! grep -qF "source $DEFAULT_ENV_FILE_PATH" "$DEFAULT_SHELL_RC" 2>/dev/null; then
  echo "source $DEFAULT_ENV_FILE_PATH" >> "$DEFAULT_SHELL_RC"
fi

###############################################
#   Homebrew installation
###############################################
echo "Installing homebrew..."
if check_installed "brew"; then
  echo "Homebrew already installed. Using $(which brew)"
else
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$OS" == "Darwin" ]]; then
    # On macOS, brew should be available after install. If not, something went wrong.
    if ! check_installed "brew"; then
      echo "Error: Homebrew installation failed on macOS. Exit."
      exit 1
    fi
  elif [[ "$OS" == "Linux" ]]; then
    if ! grep -qF 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' "$DEFAULT_ENV_FILE_PATH" 2>/dev/null; then
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$DEFAULT_ENV_FILE_PATH"
    fi
  fi
  safe_source "$DEFAULT_ENV_FILE_PATH"
  if ! check_installed "brew"; then
    echo "Error: Homebrew installation failed. exit."
    exit 1
  fi
  echo "Homebrew successfully installed."
fi

HOMEBREW_BIN_PATH=$(which brew)
# Idempotent: only add brew alias if not already present.
if ! grep -qF "function brew()" "$DEFAULT_SHELL_RC" 2>/dev/null; then
  cat >> "$DEFAULT_SHELL_RC" << EOF
# alias brew.
function brew() {
  HOMEBREW_NO_AUTO_UPDATE=1 PATH="$(dirname "$HOMEBREW_BIN_PATH"):\$PATH" $HOMEBREW_BIN_PATH "\$@"
}
EOF
fi

if ! grep -qF "$DEFAULT_MASON_PATH" "$DEFAULT_ENV_FILE_PATH" 2>/dev/null; then
  echo "PATH=\$PATH:$(brew --prefix)/bin" >> "$DEFAULT_ENV_FILE_PATH"
fi
safe_source "$DEFAULT_ENV_FILE_PATH"
safe_source "$DEFAULT_SHELL_RC"

###############################################
#   Install dependencies
###############################################
echo "Installing dependencies..."
echo "$INSTALL_DEPENDENCIES" | xargs brew install || {
  if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
    echo "Error: Failed to install some dependencies."
    exit 1
  fi
  echo "Warning: Some dependencies failed to install. Continuing..."
}

# Idempotent zoxide init.
if ! grep -qF "zoxide init" "$DEFAULT_SHELL_RC" 2>/dev/null; then
  echo "eval \"\$(zoxide init $(basename "$DEFAULT_SHELL"))\"" >> "${DEFAULT_SHELL_RC}"
fi

if check_installed "npm"; then
  npm i -g vscode-langservers-extracted
else
  echo "Warning: npm not found. Skipping vscode-langservers-extracted installation."
fi

###############################################
#   Build neovim from source (optional)
###############################################
if [ "$INSTALL_NVIM_FROM_SOURCE" -ne 0 ]; then
  echo "Install neovim to: $NVIM_INSTALL_PATH"
  mkdir -p "$NVIM_INSTALL_PATH"
  cd "$CURRENT_BASEDIR/neovim-source" && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$NVIM_INSTALL_PATH" && make install
  cd "$CURRENT_BASEDIR"

  if ! grep -qF "$NVIM_INSTALL_PATH/bin" "$DEFAULT_ENV_FILE_PATH" 2>/dev/null; then
    echo "export PATH=\"$NVIM_INSTALL_PATH/bin:\$PATH\"" >> "${DEFAULT_ENV_FILE_PATH}"
  fi
fi

###############################################
#   Symlinks
###############################################
backup_and_link() {
  local source="$1"
  local target="$2"
  if [ -z "$target" ]; then
    echo "Skipped linking $source (empty target path)"
    return
  fi

  echo "Linking $source to $target"
  if [ -L "$target" ] || [ -e "$target" ]; then
    echo "Backing up existing $target to $target.nvim.bak"
    if ! mv "$target" "$target.nvim.bak"; then
      echo "Error: Failed to back up $target. Please check permissions or manually remove/rename it."
      return 1
    fi
  else
    mkdir -p "$(dirname "$target")"
  fi

  if ln -s "$source" "$target"; then
    echo "Successfully linked $source to $target"
  else
    echo "Error: Failed to link $source to $target."
  fi
}

# Ensure using absolute paths from CURRENT_BASEDIR for sources
backup_and_link "$CURRENT_BASEDIR/config.nvim/" "${NVIM_CONF_LINK}"
backup_and_link "$CURRENT_BASEDIR/config.others/tmux.conf" "${TMUX_CONF_LINK}"
backup_and_link "$CURRENT_BASEDIR/config.others/neovide.config.toml" "${NEOVIDE_CONF_LINK}"
backup_and_link "$CURRENT_BASEDIR/config.nvim/snip" "${SNIPPET_LINK}" || [[ "$CONTINUE_ON_ERROR" == "true" ]]

###############################################
#   Font installation
###############################################
if [ -n "$INSTALL_FONT_PATH" ]; then
  echo "Installing fonts to $INSTALL_FONT_PATH..."
  mkdir -p "$INSTALL_FONT_PATH"

  if [ -d "$CURRENT_BASEDIR/monolisa-nerd-font" ]; then
    find "$CURRENT_BASEDIR/monolisa-nerd-font" -type f \( -name '*Nerd*' -o -name '*NerdFont*' \) -print0 | while IFS= read -r -d $'\0' font_file; do
      echo "Copying font: $(basename "$font_file") to $INSTALL_FONT_PATH"
      cp "$font_file" "$INSTALL_FONT_PATH/"
    done
  else
    echo "monolisa-nerd-font directory not found. Skipping font installation."
  fi

  # Update font cache on Linux
  if [[ "$OS" == "Linux" ]] && check_installed "fc-cache"; then
    echo "Updating font cache..."
    fc-cache -fv
  fi
  echo "Font installation complete."
else
  echo "INSTALL_FONT_PATH not set. Skipping font installation."
fi

###############################################
#   Environment variables
###############################################
# Idempotent writes to env file.
if ! grep -qF "OPENROUTER_API_KEY" "$DEFAULT_ENV_FILE_PATH" 2>/dev/null; then
  echo "export OPENROUTER_API_KEY=" >> "${DEFAULT_ENV_FILE_PATH}"
fi
if ! grep -qF "DEEPSEEK_API_KEY" "$DEFAULT_ENV_FILE_PATH" 2>/dev/null; then
  echo "export DEEPSEEK_API_KEY=" >> "${DEFAULT_ENV_FILE_PATH}"
fi
if ! grep -qF "$DEFAULT_MASON_PATH" "$DEFAULT_ENV_FILE_PATH" 2>/dev/null; then
  echo "export PATH=\$PATH:$DEFAULT_MASON_PATH:$HOME/.local/bin" >> "${DEFAULT_ENV_FILE_PATH}"
fi

###############################################
#   Neovim plugin installation
###############################################
safe_source "${DEFAULT_ENV_FILE_PATH}"
echo "Starting neovim to install plugins, parsers and lsps. This may take some time."

timeout 300 nvim --headless +":Lazy restore" +q || {
  if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
    echo "Warning: Lazy restore timed out or failed. Continuing..."
  else
    echo "Error: Lazy restore failed."
    exit 1
  fi
}

timeout 300 nvim --headless +"lua print('Dependencies successfully installed.')" +q || {
  if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
    echo "Warning: Neovim dependency check timed out or failed. Continuing..."
  else
    echo "Error: Neovim dependency check failed."
    exit 1
  fi
}

timeout 300 nvim --headless +"MasonToolsInstall" +q || {
  if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
    echo "Warning: MasonToolsInstall timed out or failed. Continuing..."
  else
    echo "Error: MasonToolsInstall failed."
    exit 1
  fi
}

###############################################
#   Done
###############################################
cat <<EOF

Neovim is successfully installed. Please:
  1. Setup API keys in $DEFAULT_ENV_FILE_PATH (e.g., OPENROUTER_API_KEY, DEEPSEEK_API_KEY).
  2. source $DEFAULT_SHELL_RC.
EOF
