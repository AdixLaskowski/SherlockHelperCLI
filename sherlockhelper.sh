#!/usr/bin/env bash

# ------------------------------------------- #
# Sherlockhelper
# Version: 1.0
# Author: Adrian Laskowski
# License: MIT
# Copyright (c) Adrian Laskowski 2026
# ------------------------------------------- #

set -eu -o pipefail

version="v1.0"

# ----- SETTINGS ----- #

# Turn on/off notifications
no_notify=false 

# Turn on/off notification's sound
silent_notify=false 

# If at least two arguments were given create an extra file comparison in every compared user.
# It creates a table with every webiste found for any user and marks common ones
compare=false

# Ignores given argument, if the directory about this user already exists
ignore_existing=false

# Creates a standard raport in compare mode
create_profile=false

# Shows history
show_history=false

# Do not update history for this search
no_history=false

# Shows last operation from history
show_last=false

# Notifies user every time, when a new raport is done
always_notify=false

# Gives many additional logs
debug_mode=false

# Shows help
show_help=false

# If at least 2 usernames were given
many_users=false

# ----- SHERLOCK ARGUMENTS ----- #

# Includes NSFW websites
sherlock_nsfw=false

sherlock_print_all=false

# All given usernames
usernames=()

# Sherlock arguments
sherlock_args=()

# ----- ARGUMENT PARSING ----- #
for arg in "$@"; do
    case "$arg" in
        --silent-notify)
        silent_notify=true
        ;;

        --no-notify)
        no_notify=true
        ;;

        --ignore-existing)
        ignore_existing=true
        ;;

        --compare)
        compare=true
        ;;

        --create-profile)
        create_profile=true
        ;;

        --no-history)
        no_history=true
        ;;

        --history)
        show_history=true
        ;;

        --last)
        show_last=true
        ;;

        --always-notify)
        always_notify=true
        ;;

        --debug)
        debug_mode=true
        ;;

        --help)
        show_help=true
        ;;

        # Sherlock

        --nsfw)
        sherlock_nsfw=true
        ;;

        --print-all)
        sherlock_print_all=true
        ;;

        --version)
        echo -e "Sherlock Helper $version"
        sherlock --version
        exit 0
        ;;

        -*)
        printf "Error! Unknown option: %s\n" "$arg" >&2
        exit 1
        ;;

        *)
        usernames+=("$arg")
        ;;
    esac
done

if [[ "$sherlock_nsfw" == true ]]; then
    sherlock_args+=(--nsfw)
fi

if [[ "$sherlock_print_all" == true ]]; then
    sherlock_args+=(--print-all)
fi

function display_debug_message() {

    local debug_message="$1"
    local filepath="Debug"
    local date

    date=$(date +%F_%T)

    if [[ "$debug_mode" == true ]]; then
        if [[ ! -d "$filepath" ]]; then
            mkdir -p "$filepath"
        fi   
        printf "[DEBUG MODE][%s] %s\n" "$date" "$debug_message" | tee -a "$filepath/logs.txt"
    fi
}

function show_help() {

        cat << EOF
        
SherlockHelper $version
A Bash CLI wrapper for Sherlock.

USAGE:
    ./sherlockhelper.sh [OPTIONS] USERNAME [USERNAME ...]

OPTIONS:
    --version           Display SherlockHelper and Sherlock versions

    --compare           Compare search results for multiple usernames in HTML table
    --create-profile    Create a profile when using --compare
    --ignore-existing   If some user's directory already exists, Sherlock Helper skips this username

    --nsfw              Pass the --nsfw option to Sherlock
    --print-all         Pass the --print-all option to Sherlock

    --silent-notify     Enable silent notifications
    --no-notify         Disable notifications
    --always-notify     Send notifications everytime, when a new raport is done

    --history           Display operation history
    --last              Display the last operation
    --no-history        Disable history recording for current search

    --debug             Enable debug mode

EXAMPLES:
    ./sherlockhelper.sh username1
    ./sherlockhelper.sh username1 username2
    ./sherlockhelper.sh --compare username1 username2
    ./sherlockhelper.sh --nsfw username1
    ./sherlockhelper.sh --history
    ./sherlockhelper.sh --last
    ./sherlockhelper.sh --help

For more information, see the README:
    https://github.com/AdixLaskowski/SherlockHelper

EOF
exit 0
}

if [[ "$show_help" == true ]]; then
    show_help
fi

display_debug_message "Sherlockhelper starts"
display_debug_message "Provided arguments (${#usernames[@]}): ${usernames[*]}"


if (( ${#usernames[@]} < 2 )); then
    if [[ "$compare" == true ]]; then
        printf "Error! For --compare option you need to provide at least 2 usernames.\n" >&2
        exit 1
    fi
    if [[ "$always_notify" == true ]]; then
        printf "Error! For --always-notify option you need to provide at least 2 usernames.\n" >&2
        exit 1
    fi
else
    many_users=true
fi

if [[ "$no_notify" == true ]] && [[ "$always_notify" == true ]]; then
    printf "WARNING\n"
    printf "You use both --no-notify and --always-notify options. Howewer, when --no-notify option is turned on, you won't recieve any notifications.\n"
    printf "\n"
fi

function update_history() {

    local date
    date=$(date +%F_%T)
    local operation_name="$1"
    local provided_usernames="$2"

    local history_insert="$date: $operation_name for $provided_usernames"

    if [[ "$no_history" == false ]]; then

        echo -e "$history_insert\n" >> history.md
        display_debug_message "Updated the history file - $history_insert"
    fi
}

function show_history_file() {

    echo -e "----- HISTORY -----\n"

    local path_to_history="history.md"

    if [[ -f "$path_to_history" ]]; then
        cat "$path_to_history"
    else
        echo -e "Cannot find a history file\n"
    fi

    exit 0
}

function show_last_operation() {

    local path_to_history="history.md"
    if [[ -f "$path_to_history" ]]; then
        sed '/^[[:space:]]*$/d' "$path_to_history" | tail -n 1
    fi

    exit 1
}

if [[ "$show_last" == true ]]; then
    show_last_operation
fi

if [[ "$show_history" == true ]]; then
    show_history_file
fi

# ----- SPINNER ----- #
function run_spinner() {

    local username="$1"
    local pid="$2"
    local i
    local spinner='|/-\'

    display_debug_message "Starting spinner animation"
    while kill -0 "$pid" 2>/dev/null; do
        for (( i=0; i<${#spinner}; i++ )); do # Iterating by characters in spinner variable
            printf "\rSherlock is now collecting data about %s... %s" "$username" "${spinner:i:1}" # Returning to the same line, and writing current character
            sleep 0.1
        done
    done
    printf '\r\033[K'
}

# ----- SHERLOCK ----- #
function get_sherlock_raw_results() {

    local username="$1"
    local output_file="$2"
    local pid
    local status

    # Sherlock usage (in background)
    display_debug_message "Starting Sherlock for $username"
    sherlock "$username" "${sherlock_args[@]}" > "$output_file" &
    pid=$! # Gets PID for Sherlock

    run_spinner "$username" "$pid" # Run spinner animation, while Sherlock is working...

    if wait "$pid"; then
        display_debug_message "Sherlock finished working for $username"
        return 0
    else
        status=$?
        printf "Task failed, with code: %s\n" "$status" >&2
        return "$status"
    fi
}

# Check if Sherlock is installed
if ! command -v sherlock >/dev/null 2>&1; then
    printf "Sherlock is required. You can install it from here: https://github.com/sherlock-project/sherlock\n" >&2
    exit 1
fi

# Checks if at least one argument was given
if [[ ${#usernames[@]} == 0 ]]; then
    printf "Error. No argument was given.\n" >&2
    exit 1
fi

# Creates a directory with given argument as name
function create_dir() {

    local dir_name="$1"

    if [[ ! -d "Profiles/$dir_name" ]]; then # If this directory does not exist yet
        printf "A directory for %s does not exist.\n" "$dir_name"
        printf "Creating directory...\n"
        if ! mkdir -p "Profiles/$dir_name"; then # If something went wrong while creating a directory e.g. no permissions
            printf "Cannot create a directory for %s\n" "$dir_name" >&2
            return 1
        else
            printf "A directory for %s has been successfully created\n" "$dir_name"
        fi
    fi
}

# Checks if notify-send exists, and sends a notification
function notify_user() {

    if [[ "$no_notify" == true ]]; then
        display_debug_message "Notifications are turned off"
        return
    fi

    local title="$1"
    local message="$2"

    # Checks if notify-send is installed
    if command -v notify-send >/dev/null 2>&1; then
        if ! notify-send "$title" "$message"; then
            printf "Error. Cannot send the notification.\n" >&2
        fi
    else
        printf "Error. notify-send cannot be found.\n" >&2
    fi

    # Checks if pw-play is installed, and the selected sound exists

    if [[ "$silent_notify" == false ]]; then

        local sound='/usr/share/sounds/freedesktop/stereo/message.oga'

        if command -v pw-play >/dev/null 2>&1; then
            if [[ -f "$sound" ]]; then
                if ! pw-play "$sound"; then
                    printf "Error. Cannot play notification sound.\n" >&2
                fi
            else
                printf "Error. Provided sound cannot be found.\n" >&2
            fi 
        else
            printf "Error. pw-play cannot be found.\n" >&2
        fi
    fi
}

# ----- Generates a tsv file for comparations ----- #
function prepare_data_to_compare() {

    display_debug_message "Preparing data for comparation"

    local arg="$1"
    local raw_data="$2"
    local output_file="$3"

    awk -v arg="$arg" '
    /^\[\+\]/{
        sub(/^\[\+\][[:space:]]*/, "") # Removes [+]
        pos = index($0, ": ") # Finding : in current line

        if(pos > 0)
        {
            name = substr($0, 1, pos - 1) # Everything before : is a website name
            link = substr($0, pos + 2) # Everything after : is a link

            printf "%s\t%s\t%s\n", arg, name, link # Setting Username, website name and link into the table
        }
    }
   ' "$raw_data" >> "$output_file" # Add results to the file

}

# ----- Generates a comparation raport ----- #
function compare() {

    display_debug_message "Comparating given usernames"

    local input_file="$1"
    local output_file="$2"
    local date
    date=$(date +'%F %T')

    printf "# Sherlock comparison %s\n" "$date" > "$output_file"
    awk -F '\t' '
    {
        username = $1
        website = $2
        link = $3

        records_count[username]++

        if(!(username in users_seen))
        {
            users_seen[username] = 1
            users[++user_count] = username
        }

        if(!(website in websites_seen))
        {
            websites_seen[website] = 1
            websites[++websites_count] = website
        }

        links[username, website] = link

        if (link != "")
        {
            all_records_count[username]++
            total_records++
        }
    }
    END {
        
        printf "#### Unique websites found: %s\n", websites_count

        for(i=1; i<=user_count; i++)
        {
            username = users[i]
            printf "#### Records found for %s: %d\n", username, records_count[username]
        }

        printf "### Total records found: %s\n", total_records

        print "<div style=\"overflow-x: auto;\">"
        print "<table style=\"border: 1px solid white; border-collapse: collapse; width: 100%;\">"

        printf "<tr style=\"border: 1px solid white; border-collapse: collapse; padding: 10px; text-align: center;\"><th style=\"border: 1px solid white; border-collapse: collapse; padding: 10px; text-align: center;\">#</th>"
        printf "<th style=\"border: 1px solid white; border-collapse: collapse; padding: 10px; text-align: center;\">Website</th>"
        for (i=1; i<=user_count; i++)
        {
            printf "<th style=\"border: 1px solid white; border-collapse: collapse; padding: 10px; text-align: center;\">%s</th>", users[i]
        }

        printf "</tr>"

        for(j=1; j<=websites_count; j++)
        {
            website = websites[j]
            printf "<tr style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\"><td style=\"border: 1px solid white; border-collapse: collapse; padding: 10px; text-align: center;\">%i</td>", j
            printf "<td style=\"border: 1px solid white; border-collapse: collapse; padding: 10px; text-align: center;\">%s</td>", website

            for(i=1; i<=user_count; i++)
            {
                username = users[i]

                if((username, website) in links)
                {
                    printf "<td style=\"border: 1px solid white; border-collapse: collapse; padding: 10px; text-align: center;\"><a href=\"%s\">Profile</a></td>", links[username, website]

                }else{print "<td style=\"border: 1px solid white;border-collapse: collapse; padding: 10px; text-align: center;\"><span style=\"color: red ;\">NOT FOUND</span></td>"}
            }
            print "</tr>"
        }
        
        print "</table>"
        print "</div>"
    }
    
    ' "$input_file" >> "$output_file"

    compared_usernames=$(awk '!seen[$1]++ { printf "%s%s", sep, $1; sep=" " } END { print "" }' "$input_file")

    update_history "Comparation" "$compared_usernames"

}

# ----- Generates a standard raport ----- #
function generate_standard_user_report() {

    display_debug_message "Generating standard raport"

    local username="$1"
    local raw_data="$2"
    local many_users="$3"
    local filepath="Profiles/$username/results.md"
    local results_found
    local date
    date=$(date +'%F %T')

    printf "# %s search results $date\n" "$username" > "$filepath" # Main header

    # Count results
    results_found=$(grep -Fc '[+]' "$raw_data" || true)
    display_debug_message "Sherlock found $results_found results"

    if (( results_found == 0 )); then
        printf "### Sherlock found nothing\n" >> "$filepath" # No Results found
        notify_user "Task done" "Nothing was found."
        return 0
    else
        printf "### Matching profiles found: %i\n" "$results_found" >> "$filepath"
    fi
    
    awk '
    BEGIN{
        print "<table style=\"border: 1px solid white; border-collapse: collapse;\">"  # Opening HTML table
        print "<tr style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\"><th style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\">#</th><th style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\">Website</th><th style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\">Link</th></tr>" # Headers
    }
    /^\[\+\]/{
        sub(/^\[\+\][[:space:]]*/, "") # Removes [+]
        pos = index($0, ": ") # Finding : in current line

        if(pos > 0)
        {
            name = substr($0, 1, pos - 1) # Everything before : is a website name
            link = substr($0, pos + 2) # Everything after : is a link

            printf "<tr style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\"><td style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\">%i</td><td style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\">%s</td><td style=\"border: 1px solid white; border-collapse: collapse; text-align: center;\"><a href=\"%s\">%s</a></td></tr>\n", ++i, name, link, link # Setting Website name and link into the table
        }
    }
    END{
        print "</table>" # Closing HTML table
    }' "$raw_data" >> "$filepath" # Add results to the file

    update_history "Standard raport" "$username"

    if [[ "$many_users" == false ]] || [[ "$always_notify" == true ]]; then
        notify_user "Sherlock Helper" "A raport about $arg is ready"
    fi
}

if [[ "$compare" == true ]]; then
    display_debug_message "Creating a temporary file for data to compare"
    data_to_compare=$(mktemp)
fi

# Sets many_users varriable
if (( "${#usernames[@]}" >= 2)); then
    many_users=true
fi

# ----- MAIN LOOP ----- #
overall_status=0
for arg in "${usernames[@]}";
do
     if [[ -d "Profiles/$arg" ]] && [[ "$ignore_existing" == true ]] && [[ "$compare" == false ]]; then
        display_debug_message "Skipping an iteration for $arg due --ignore_existing option"
        continue
    fi

    # Creating a directory for a username
    if [[ "$compare" == false ]] || [[ "$create_profile" == true ]]; then
        if ! create_dir "$arg"; then
            printf "Cannot create a directory.\n" >&2
            overall_status=1
            continue
        fi
    fi

    # A temporary file for a raw Sherlock results
    tmp_raw_data=$(mktemp) 
    trap 'rm -f "$tmp_raw_data"' EXIT # Removes the temporary file when unexpected exit has occured

    if get_sherlock_raw_results "$arg" "$tmp_raw_data"; then
        if [[ "$compare" == true ]]; then
            if [[ "$create_profile" == true ]]; then
                generate_standard_user_report "$arg" "$tmp_raw_data" "$many_users"
            fi
            prepare_data_to_compare "$arg" "$tmp_raw_data" "$data_to_compare"
        else
            generate_standard_user_report "$arg" "$tmp_raw_data" "$many_users"
        fi

    else
        overall_status=1
        notify_user "Unexpected Error!" "Some unexpected error has occured"
        rm -f "$tmp_raw_data"
        continue
    fi

    printf "\r\033[K"
    rm -f "$tmp_raw_data" # Manually removes temporary file, with a raw Sherlock output

    if [[ "$many_users" == true ]] && [[ "$always_notify" == true ]]; then
        notify_user "Task done" "Raport about $arg is ready."
    fi
done

if [[ "$compare" == true ]]; then
    mkdir -p Comparisons

    output_file="Comparisons/comparision_$(date +%Y-%m-%d_%H%M%S).md"

    compare "$data_to_compare" "$output_file"

    rm -f "$data_to_compare"

    printf "Comparation saved to %s\n" "$output_file"
    notify_user "Task done" "A new comparation is ready."
fi

# At the end
if [[ "$overall_status" == 0 ]]; then
    printf "All tasks done successfully.\n"
    if [[ "$many_users" == true ]] && [[ "$always_notify" == false ]] && [[ "$compare" == false ]]; then
        notify_user "Sherlock Helper" "Everything is ready."
    fi
fi

exit "$overall_status"
