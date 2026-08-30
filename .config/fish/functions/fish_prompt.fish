function fish_prompt --description 'Write out the prompt'
    set -l last_pipestatus $pipestatus
    set -l normal (set_color normal)

    # If starship is installed, let it handle the prompt
    if type -q starship
        return
    end

    # Color definitions (Tokyo Night)
    set -l color_cwd (set_color 7dcfff)
    set -l color_git (set_color bb9af7)
    set -l color_arrow (set_color 7aa2f7)
    set -l color_error (set_color f7768e)

    # Git branch
    set -l git_info ""
    if command -v git >/dev/null 2>&1
        set -l branch (command git symbolic-ref --short HEAD 2>/dev/null; or command git rev-parse --short HEAD 2>/dev/null)
        if test -n "$branch"
            set git_info " on $color_git$branch$normal"
        end
    end

    # Status arrow color
    set -l arrow_color $color_arrow
    for status_code in $last_pipestatus
        if test $status_code -ne 0
            set arrow_color $color_error
            break
        end
    end

    # Keep the prompt on one line. A literal \n here is rendered by some Fish
    # versions instead of being treated as a line break.
    printf '%s%s%s%s%s%s%s❯ %s' (set_color 7aa2f7) "󰣇 " $color_cwd (prompt_pwd) $normal $git_info $arrow_color $normal
end
