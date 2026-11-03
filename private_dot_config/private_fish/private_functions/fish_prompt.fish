function fish_prompt
    set -l suffix ''
    set -l is_root 0

    if test (id -u) -eq 0
        set is_root 1
        set suffix (set_color red | string collect --allow-empty)' root'
    end

    if functions -q __prompt_git
        set -l git_info (__prompt_git | string collect)
        if test -n "$git_info"
            set suffix "$suffix"(set_color brblack | string collect --allow-empty)' │ '"$git_info"
        end
    end

    if set -q __prompt_has_run
        if test "$__prompt_last_status" -ne 0
            set suffix "$suffix"(set_color brblack | string collect --allow-empty)' │ '(set_color red | string collect --allow-empty)"ERROR $__prompt_last_status"
        end

        set -l ms $__prompt_last_duration
        set -l timing "$__prompt_start"
        if test "$ms" -gt 60000
            set timing "$__prompt_start → $__prompt_end"
        end
        set suffix "$suffix"(set_color brblack | string collect --allow-empty)' │ '(set_color brblue | string collect --allow-empty)"$timing"
        set -l duration

        if test "$ms" -lt 1000
            set duration "$ms"ms
        else if test "$ms" -lt 60000
            set duration (math -s 0 "floor($ms / 1000)")s
        else if test "$ms" -lt 3600000
            set -l minutes (math -s 0 "floor($ms / 60000)")
            set -l seconds (math -s 0 "floor(($ms % 60000) / 1000)")
            set duration "$minutes"m" $seconds"s
        else
            set -l hours (math -s 0 "floor($ms / 3600000)")
            set -l minutes (math -s 0 "floor(($ms % 3600000) / 60000)")
            set -l seconds (math -s 0 "floor(($ms % 60000) / 1000)")
            set duration "$hours"h" $minutes"m" $seconds"s
        end

        set suffix "$suffix"(set_color yellow | string collect --allow-empty)" $duration"
    end
    set suffix "$suffix"(set_color normal | string collect --allow-empty)

    # Use a separate display variable: Fish's $path controls command lookup.
    set -l display_path "$PWD"
    if string match -q -- "$HOME/*" "$PWD"
        set display_path (string replace -- "$HOME/" '~/' "$PWD")
    end

    # Fish truncates an oversized prompt line. Insert real line breaks first,
    # preserving terminal color sequences and Unicode grapheme clusters.
    set -l identity (id -un)'@'(prompt_hostname)
    set -l context (set_color green | string collect --allow-empty)"$identity "(set_color cyan | string collect --allow-empty)"$display_path"(set_color normal | string collect --allow-empty)"$suffix"
    set -l width 79
    if set -q COLUMNS; and test "$COLUMNS" -gt 1
        set width (math "$COLUMNS - 1")
    end
    set -l used 0
    for token in (string match --all --regex '\e\[[0-?]*[ -/]*[@-~]|\X' -- "$context")
        set -l token_width (string length --visible -- "$token")
        if test "$token_width" -gt 0
            if test (math "$used + $token_width") -gt "$width"
                printf '\n'
                set used 0
            end
            set used (math "$used + $token_width")
        end
        printf '%s' "$token"
    end
    printf '\n'

    if test "$is_root" -eq 1
        set_color red
    else
        set_color white
    end
    printf '; '
    set_color normal
end
