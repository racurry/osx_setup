# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh
ZSH_THEME=""

HYPHEN_INSENSITIVE="true"

# Display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

plugins=(git bundler rake)

# Homebrew and ASDF setup
# Ensure Homebrew is on the path and asdf is sourced
# (Order matters if asdf is installed via Homebrew)
eval "$(/opt/homebrew/bin/brew shellenv)"
. /opt/homebrew/opt/asdf/libexec/asdf.sh

# Use the pure prompt
autoload -U promptinit; promptinit
prompt pure

# The fuck
eval $(thefuck --alias)

export LANG=en_US.UTF-8
export EDITOR='vim'

# Keep less from paginating unless it needs to
export LESS="-FRXK"

# History
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=50000
HISTDUP=erase # Erase duplicates in the history file
setopt appendhistory # Append history to the history file (no overwriting)
setopt sharehistory # Share history across terminals
setopt incappendhistory # Immediately append to the history file, not just when a term is killed
unsetopt nomatch # Don't throw an error if there are no matches, just do the right thing

# Set up NPM_TOKEN if .npmrc exists
if [ -f ~/.npmrc ]; then
  export NPM_TOKEN=`sed -n -e '/_authToken/ s/.*\= *//p' ~/.npmrc`
fi

# Workspace shortcuts
export workspace=~/Documents/workspace
export inbox=~/Documents/Inbox

# Grab any galileo-specific aliases & configs
if [ -f ~/.galileorc ]; then
  source ~/.galileorc
fi

# Automatically ls after cd
cd () {
  builtin cd "$@";
  ls -a;
}

# Slightly more user-friendly man pages
tldr () {
  curl "cheat.sh/$1"
}

# Kill process on a port
findandkill() {  
  lsof -n -i:$1 | grep LISTEN | awk '{ print $2 }' | uniq | xargs kill -9
} 
alias killport=findandkill

# Homebrew (Apple Silicon) paths for libraries and headers
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/bison/lib -L/opt/homebrew/opt/openssl@3/lib -L/opt/homebrew/opt/readline/lib -L/opt/homebrew/opt/libyaml/lib -L/opt/homebrew/opt/gmp/lib"
export CPPFLAGS="-I/opt/homebrew/opt/bison/include -I/opt/homebrew/opt/openssl@3/include -I/opt/homebrew/opt/readline/include -I/opt/homebrew/opt/libyaml/include -I/opt/homebrew/opt/gmp/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/bison/lib/pkgconfig:/opt/homebrew/opt/openssl@3/lib/pkgconfig:/opt/homebrew/opt/readline/lib/pkgconfig:/opt/homebrew/opt/libyaml/lib/pkgconfig:/opt/homebrew/opt/gmp/lib/pkgconfig"

# For Ruby builds (asdf, ruby-build, etc.)
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"

# PATH modifications (grouped)
export PATH="$PATH:$workspace/helper-scripts/bin:/Users/aaron/.local/bin"

# Aliases and convenience functions
alias rezsh="source ~/.zshrc"
alias zshconfig="code -nw ~/workspace/osx_setup/data/dotfiles/.zshrc"
alias ohmyzsh="code -nw ~/.oh-my-zsh"
# Enhanced ls: show all files and use color
alias ls="ls -aG"
# bundler
alias be="bundle exec"
# Fix zsh breaking rake like a total turd
alias rake='noglob rake'

