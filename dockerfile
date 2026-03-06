FROM --platform=linux/amd64 ubuntu:22.04

ARG LISTEN_IP=0.0.0.0
ARG LISTEN_PORT=9099
ARG DEBIAN_FRONTEND=noninteractive
EXPOSE 9099

# Install base dependencies via apt (faster than brew for Docker).
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    zsh curl coreutils git gcc g++ make cmake ca-certificates sudo \
    unzip zip xsel nodejs npm ripgrep fd-find \
    lua5.4 luarocks libsqlite3-dev sqlite3 \
    fontconfig locales \
  && rm -rf /var/lib/apt/lists/* \
  && ln -sf /usr/bin/fdfind /usr/bin/fd

# Install neovim from official release (apt version is too old).
RUN curl -fsSL https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz \
  | tar -C /opt -xzf - \
  && ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim

# Install lazygit from GitHub release.
RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
    | grep -Po '"tag_name": *"v\K[^"]*') \
  && curl -fsSLo lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
  && tar xf lazygit.tar.gz lazygit \
  && install lazygit /usr/local/bin/ \
  && rm -f lazygit.tar.gz lazygit

# Install zoxide.
RUN curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

# Install fzf.
RUN curl -fsSL https://github.com/junegunn/fzf/releases/latest/download/fzf-$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep -Po '"tag_name": *"v?\K[^"]*')-linux_amd64.tar.gz \
  | tar -C /usr/local/bin -xzf -

# Install GitHub CLI.
RUN (type -p wget >/dev/null || apt-get install -y wget) \
  && mkdir -p -m 755 /etc/apt/keyrings \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update \
  && apt-get install -y gh \
  && rm -rf /var/lib/apt/lists/*

# Install vscode-langservers-extracted.
RUN npm i -g vscode-langservers-extracted

# Copy configuration.
COPY . /app/

# Link neovim config.
RUN mkdir -p /root/.config \
  && ln -sf /app/config.nvim /root/.config/nvim

# Install plugins with timeout.
RUN timeout 300 nvim --headless +":Lazy restore" +q 2>&1 || true
RUN timeout 300 nvim --headless +"lua print('Plugins loaded.')" +q 2>&1 || true

# Extract entrypoint to standalone file for reliability.
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
