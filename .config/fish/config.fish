if status is-interactive
    set -g fish_greeting "Welcome back, $USER 🐟"
    # Commands to run in interactive sessions can go here

    zoxide init fish | source

    # --- Exports ---
    set -x BUN_INSTALL $HOME/.bun
    set -x EDITOR nvim
    set -x aurhelper yay

# --- Aliases ---
alias c 'clear'
alias l 'eza -lh --icons=auto'
alias ls 'eza -1 --icons=auto'
alias ll 'eza -lha --icons=auto --sort=name --group-directories-first'
alias ld 'eza -lhD --icons=auto'
alias lt 'eza --icons=auto --tree'

alias un '$aurhelper -Rns'
alias up '$aurhelper -Syu'
alias pl '$aurhelper -Qs'
alias pa '$aurhelper -Ss'
alias pc '$aurhelper -Sc'
alias po '$aurhelper -Qtdq | $aurhelper -Rns -'

alias vc 'code'
alias vim 'nvim'
alias aa 'startx'
alias rm 'trash -v'
alias hx 'helix'
alias ff 'fastfetch'

alias .. 'cd ..'
alias ... 'cd ../..'
alias .3 'cd ../../..'
alias .4 'cd ../../../..'
alias .5 'cd ../../../../..'

alias mkdir 'mkdir -p'

# if you wanna add github token
# set -x GITHUB_TOKEN 

# --- Tide Prompt Elements ---
# Left side:  OS icon | current directory | git branch & status | prompt character
# Right side: command status | execution time | user@host | background jobs | python version | go version | current time

function aur-search
    # Search AUR packages with fzf preview
    yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S
end

function git-sync
    # Quick: add all, commit with message, push
    git add .
    git commit -m "$argv"
    git push
end

# --- PATH Configuration ---
set -gx PATH $HOME/.local/bin $HOME/.cargo/bin $BUN_INSTALL/bin $PATH

# --- Display fastfetch on interactive startup ---
if test -z "$TMUX" && type -q fastfetch
    fastfetch
end

end
