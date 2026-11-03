
function __prompt_git
    command git rev-parse --is-inside-work-tree \
        2>/dev/null | string match -q true
    or return

    # Branch name, or short commit hash if detached
    set -l branch (command git symbolic-ref --short HEAD 2>/dev/null)
    if test -z "$branch"
        set branch (command git rev-parse --short HEAD 2>/dev/null)
    end

    set_color green
    printf '%s' "$branch"

    # Compare against locally known upstream refs; never fetch from the prompt.
    set -l divergence (command git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    if test $status -eq 0
        set -l counts (string split --no-empty -- "	" "$divergence")
        if test (count $counts) -eq 2
            if test "$counts[1]" -gt 0
                set_color brgreen
                printf ' ↑ %s ahead' "$counts[1]"
            end
            if test "$counts[2]" -gt 0
                set_color brmagenta
                printf ' ↓ %s behind' "$counts[2]"
            end
        end
    end

    set -l staged 0
    set -l modified 0
    set -l untracked 0
    set -l conflicts 0

    set -l entries (command git status --porcelain=v1 \
        --untracked-files=normal)

    for entry in $entries
        set -l xy (string sub -s 1 -l 2 -- "$entry")
        set -l x (string sub -s 1 -l 1 -- "$xy")
        set -l y (string sub -s 2 -l 1 -- "$xy")

        if test "$xy" = '??'
            set untracked (math $untracked + 1)
        else if contains -- "$xy" DD AU UD UA DU AA UU
            set conflicts (math $conflicts + 1)
        else
            if contains -- "$x" M A D R C T
                set staged (math $staged + 1)
            end

            if contains -- "$y" M D T
                set modified (math $modified + 1)
            end
        end
    end

    if test $staged -eq 0 -a $modified -eq 0 \
        -a $untracked -eq 0 -a $conflicts -eq 0
        set_color green
        printf ' ✓ clean'
    else
        if test $staged -gt 0
            set_color green
            printf ' ● %s staged' $staged
        end
        if test $modified -gt 0
            set_color yellow
            printf ' * %s modified' $modified
        end
        if test $untracked -gt 0
            set_color brred
            printf ' ? %s untracked' $untracked
        end
        if test $conflicts -gt 0
            set_color red
            printf ' ! %s conflicts' $conflicts
        end
    end

    set_color normal
end

