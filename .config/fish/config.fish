if status is-interactive
    set -g fish_greeting "Welcome back, $USER 🐟"
    # Commands to run in interactive sessions can go here

    if type -q zoxide
        zoxide init fish | source
    end

    # --- Exports ---
    set -x BUN_INSTALL $HOME/.bun
    set -x EDITOR nvim

# --- Aliases ---
alias c 'clear'
alias l 'eza -lh --icons=auto'
alias ls 'eza -1 --icons=auto'
alias ll 'eza -lha --icons=auto --sort=name --group-directories-first'
alias ld 'eza -lhD --icons=auto'
alias lt 'eza --icons=auto --tree'

alias vc 'code'
alias vim 'nvim'
alias aa 'startx'
# rm alias with safety check
if command -v trash >/dev/null 2>&1
    alias rm 'trash -v'
else
    echo "note: trash not installed, rm alias not created. Install trash-cli (or your distro's trash package) to enable safe deletion."
end
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

# Cleanup stale Tide universal prompt variables if needed
# Usage: tide_cleanup
function tide_cleanup
    for var in (set -U --names | string match '_tide_prompt_*')
        set -eU $var
    end
    echo "Removed stale Tide prompt universal variables."
end

function __dotfiles_pkg_backend
    if type -q yay
        echo yay
    else if type -q paru
        echo paru
    else if type -q apt-get
        echo apt-get
    else if type -q dnf
        echo dnf
    else if type -q zypper
        echo zypper
    else if type -q emerge
        echo emerge
    else if type -q pacman
        echo pacman
    end
end

function up
    set -l backend (__dotfiles_pkg_backend)
    switch $backend
        case yay paru
            command $backend -Syu
        case pacman
            sudo pacman -Syu
        case apt-get
            sudo apt-get update; and sudo apt-get upgrade -y
        case dnf
            sudo dnf upgrade --refresh -y
        case zypper
            sudo zypper refresh; and sudo zypper update -y
        case emerge
            sudo emerge --ask --verbose --update --deep --newuse @world
        case '*'
            echo "No supported package manager found."
            return 1
    end
end

function un
    if test (count $argv) -eq 0
        echo "Usage: un <package> [package ...]"
        return 1
    end

    set -l backend (__dotfiles_pkg_backend)
    switch $backend
        case yay paru
            command $backend -Rns $argv
        case pacman
            sudo pacman -Rns $argv
        case apt-get
            sudo apt-get remove --autoremove $argv
        case dnf
            sudo dnf remove -y $argv
        case zypper
            sudo zypper remove -y $argv
        case emerge
            sudo emerge --ask --depclean $argv
        case '*'
            echo "No supported package manager found."
            return 1
    end
end

function pl
    if test (count $argv) -eq 0
        echo "Usage: pl <search-term> [search-term ...]"
        return 1
    end

    set -l backend (__dotfiles_pkg_backend)
    switch $backend
        case yay paru pacman
            command $backend -Qs $argv
        case apt-get
            dpkg -l | grep -i -- $argv
        case dnf
            dnf list installed | grep -i -- $argv
        case zypper
            zypper search --installed-only $argv
        case emerge
            emerge --search @installed $argv
        case '*'
            echo "No supported package manager found."
            return 1
    end
end

function pa
    if test (count $argv) -eq 0
        echo "Usage: pa <search-term> [search-term ...]"
        return 1
    end

    set -l backend (__dotfiles_pkg_backend)
    switch $backend
        case yay paru pacman
            command $backend -Ss $argv
        case apt-get
            apt-cache search $argv
        case dnf
            dnf search $argv
        case zypper
            zypper search $argv
        case emerge
            emerge --search $argv
        case '*'
            echo "No supported package manager found."
            return 1
    end
end

function pc
    set -l backend (__dotfiles_pkg_backend)
    switch $backend
        case yay paru pacman
            sudo pacman -Sc
        case apt-get
            sudo apt-get clean
        case dnf
            sudo dnf clean all
        case zypper
            sudo zypper clean --all
        case emerge
            eclean-dist --deep
        case '*'
            echo "No supported package manager found."
            return 1
    end
end

function po
    set -l backend (__dotfiles_pkg_backend)
    switch $backend
        case yay paru
            set -l orphans (command $backend -Qtdq)
            test -n "$orphans"; and command $backend -Rns $orphans
        case pacman
            set -l orphans (pacman -Qtdq)
            test -n "$orphans"; and sudo pacman -Rns $orphans
        case apt-get
            sudo apt-get autoremove -y
        case dnf
            sudo dnf autoremove -y
        case zypper
            sudo zypper packages --orphaned
        case emerge
            sudo emerge --ask --depclean
        case '*'
            echo "No supported package manager found."
            return 1
    end
end

function aur-search
    # Search Arch AUR packages with fzf preview when an AUR helper is available
    if not type -q fzf
        echo "fzf not found. Install fzf to use aur-search."
        return 1
    end

    if type -q yay
        set -l packages (yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75%)
        test (count $packages) -gt 0; and yay -S $packages
    else if type -q paru
        set -l packages (paru -Slq | fzf --multi --preview 'paru -Si {1}' --preview-window=down:75%)
        test (count $packages) -gt 0; and paru -S $packages
    else
        echo "AUR helper not found. This command is only available on Arch-based systems."
        return 1
    end
end

function git-sync
    # Quick: add all, commit with message, push
    if test (count $argv) -eq 0
        echo "Usage: git-sync <commit message>"
        return 1
    end

    git add .
    git commit -m (string join ' ' -- $argv)
    git push
end

# --- PATH Configuration ---
set -gx PATH $HOME/.local/bin $HOME/.cargo/bin $BUN_INSTALL/bin $PATH

# --- Display fastfetch on interactive startup ---
if test -z "$TMUX" && type -q fastfetch
    fastfetch
end

end
