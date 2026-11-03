if status is-interactive
    set -g fish_greeting ''

    # Capture command timing once per execution, including commands that fail.
    function __prompt_command_start --on-event fish_preexec
        set -g __prompt_start (command date '+%H:%M:%S')
    end

    function __prompt_command_end --on-event fish_postexec
        set -g __prompt_last_status $status
        set -g __prompt_last_duration $CMD_DURATION
        set -g __prompt_end (command date '+%H:%M:%S')
        set -g __prompt_has_run 1
    end
end
