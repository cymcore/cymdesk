#!/bin/bash

#COLORIZING

#===================   COLORIZING  OUTPUT =================
declare -A colors
colors=(
  [None]='\033[0m'
  [Bold]='\033[01m'
  [Disable]='\033[02m'
  [Underline]='\033[04m'
  [Reverse]='\033[07m'
  [Strikethrough]='\033[09m'
  [Invisible]='\033[08m'
  [Black]='\033[0;30m'        # Black
  [Red]='\033[0;31m'          # Red
  [Green]='\033[0;32m'        # Green
  [Yellow]='\033[0;33m'       # Yellow
  [Blue]='\033[0;34m'         # Blue
  [Purple]='\033[0;35m'       # Purple
  [Cyan]='\033[0;36m'         # Cyan
  [White]='\033[0;37m'        # White
  # Bold
  [BBlack]='\033[1;30m'       # Black
  [BRed]='\033[1;31m'         # Red
  [BGreen]='\033[1;32m'       # Green
  [BYellow]='\033[1;33m'      # Yellow
  [BBlue]='\033[1;34m'        # Blue
  [BPurple]='\033[1;35m'      # Purple
  [BCyan]='\033[1;36m'        # Cyan
  [BWhite]='\033[1;37m'       # White
  # Underline
  [UBlack]='\033[4;30m'       # Black
  [URed]='\033[4;31m'         # Red
  [UGreen]='\033[4;32m'       # Green
  [UYellow]='\033[4;33m'      # Yellow
  [UBlue]='\033[4;34m'        # Blue
  [UPurple]='\033[4;35m'      # Purple
  [UCyan]='\033[4;36m'        # Cyan
  [UWhite]='\033[4;37m'       # White
)
num_colors=${#colors[@]}
# -----------------------------------------------------------


# ==================== USE THIS FUNCTION TO PRINT TO STDOUT =============
# $1: color  - if not exists, then normal output is used
# $2: text to print out
# $3: no_newline - if nothing is provided newline will be printed at the end
#                 - anything provided, NO newline is indicated
# c_print "White" "Testing dependencies (jq)..." 1
function c_print ()
{
  color=$1
  text=$2
  no_newline=$3

  #if color exists/defined in the array
  if [[ ${colors[$color]} ]]
  then
    text_to_print="${colors[$color]}${text}${colors[None]}" #colorized output
  else
    text_to_print="${text}" #normal output
  fi

  if [ -z "$no_newline" ]
  then
    echo -e $text_to_print # newline at the end
  else
    #this is the case when we want to add status like [DONE] at the end of the line after
    #a function has finished. Hence, we pad the original text with whitespaces accordingly
    size=${#text_to_print}
    cols=$(echo $(/usr/bin/tput cols))
    fixed_status_length=6 #e.g., [DONE], [FAIL]
    pad_size=`expr $cols - $size - $fixed_status_length` #the final size of the padding
    #we use printf to print the padding, instead of for loops and echo
    pad=$(printf "%*s" "$pad_size")

    echo -en "${text_to_print}${pad}" # NO newline at the end
	fi

}


function check_retval ()
# Usage: retval=$(echo $?)
{
  retval=$1
  if [ $retval -ne 0 ]
  then
    c_print "BRed" "[FAIL]"
    exit -1
  else
    c_print "BGreen" "[DONE]"
  fi
}

GetDictionaryItemFromArrayItem() {
# Usage: emulates a dictionary interation.  Pass a formatted array element and delcared dictionary.
# Example format:
#     users=(
#     "name=Alice;age=25;city=New York"
#     "name=Bob;age=30;city=Los Angeles"
# )
# How to use in your code:
# for user in "${users[@]}"; do 
#     declare -A user_info  
#     GetDictionaryItemFromArrayItem "$user" user_info  # Pass quoted user string

#     # Access dictionary values
#     echo "Name: ${user_info[name]}"
#     echo "Age: ${user_info[age]}"
#     echo "City: ${user_info[city]}"
#     echo "--------------------"
# done

    local arrayItem="$1"       # Input string
    local -n dictItem=$2       # Reference to the associative array (no need to redeclare)

    IFS=";" read -r -a key_value_pairs <<< "$arrayItem"
    # Populate dictionary
    for pair in "${key_value_pairs[@]}"; do
        IFS="=" read -r key value <<< "$pair"
        if [[ -n "$key" && -n "$value" ]]; then  # Ensure both key and value exist
            dictItem[$key]=$value
        fi
    done
}