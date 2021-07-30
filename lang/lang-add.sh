#!/bin/bash
#
# Version 1.0.1 Build 18
#
# lang-add.sh - multi-language support script
#  add new texts from list (lang_add.txt) to all dictionary files
#
# Input files:
#  lang_add.txt
# Updated files:
#  lang_en.txt and all lang_en_xx.txt
#
#############################################################################
# Change log:
#  1 Nov 2018,  Xpilla,     Initial
#  9 June 2020, 3d-gussner, Added version and Change log
#  9 June 2020, 3d-gussner, colored output
#  1 Mar. 2021, 3d-gussner, Add Community language support
#  2 Apr. 2021, 3d-gussner, Use `git rev-list --count HEAD lang-add.sh`
#                           to get Build Nr
# 30 June 2021, wavexx    , avoid repetition for supported languages
#                           handle duplicate translations and empty files
#                           add a *crude* metadata extractor
# 30 July 2021, 3d-gussner, Prevent double messages
#############################################################################

# List of supported languages
LANGUAGES="cz de es fr it pl"

# Community languages
LANGUAGES+=" nl" #Dutch

# Set defaults
skip_insert="0"

# check single text in english dictionary
# $1 - text to check
# $2 - metadata
check_en()
{
if grep "$1" lang_en.txt >/dev/null; then
    echo "$(tput setaf 3)text already exist in en:"
    echo "$1$(tput sgr0)"
    echo
    skip_insert="1"
else
    skip_insert="0"
fi
if [ ! -z "$2" ]; then
    if grep "$2" lang_en.txt >/dev/null; then
        echo "$(tput setaf 3)Meta already exist in en:"
        echo "$2$(tput sgr0)"
        echo
        skip_insert="1"
    else
        skip_insert="0"
    fi
fi
}

# insert single text to english dictionary
# $1 - text to insert
# $2 - metadata
insert_en()
{
    echo "$(tput sgr0)Inserting meta: $(tput setaf 2)$2$(tput sgr0) text: $(tput setaf 2)$1$(tput sgr0) in $(tput setaf 2)en$(tput sgr0)"
    #replace '[' and ']' in string with '\[' and '\]'
    str=$(echo "$1" | sed "s/\[/\\\[/g;s/\]/\\\]/g")
    # extract english texts, merge new text, grep line number
    ln=$((cat lang_en.txt; echo "$1") | sed "/^$/d;/^#/d" | sort | grep -n "$str" | sed "s/:.*//;q")
    # calculate position for insertion
    ln=$((3*(ln-2)+1))
    [ "$ln" -lt 1 ] && ln=1
    # insert new text
    sed -i "$ln"'i\\' lang_en.txt
    sed -i "$ln"'i\'"$1"'\' lang_en.txt
    sed -i "${ln}i\\#$2" lang_en.txt
}

# check single text in translated dictionary
# $1 - text to check
# $2 - suffix
# $3 - metadata
check_xx()
{
if grep "$1" lang_en_$2.txt >/dev/null; then
    echo "$(tput setaf 3)text already exist in $2:"
    echo "$1$(tput sgr0)"
    echo
    skip_insert="1"
else
    skip_insert="0"
fi
#if [[ ! -z "$3" && "$skip_insert"="0" ]]; then
if [ ! -z "$3" ]; then
    if grep "$3" lang_en_$2.txt >/dev/null; then
        echo "$(tput setaf 3)Meta already exist in $2:"
        echo "$3$(tput sgr0)"
        echo
        skip_insert="1"
    else
        skip_insert="0"
    fi
fi
}

# insert single text to translated dictionary
# $1 - text to insert
# $2 - suffix
# $3 - metadata
insert_xx()
{
    echo "$(tput sgr0)Inserting meta: $(tput setaf 2)$3$(tput sgr0) text: $(tput setaf 2)$1$(tput sgr0) in $(tput setaf 2)$2$(tput sgr0)"
    #replace '[' and ']' in string with '\[' and '\]'
    str=$(echo "$1" | sed "s/\[/\\\[/g;s/\]/\\\]/g")
    # extract english texts, merge new text, grep line number
    ln=$((cat lang_en_$2.txt; echo "$1") | sed "/^$/d;/^#/d" | sed -n 'p;n' | sort | grep -n "$str" | sed "s/:.*//;q")
    # calculate position for insertion
    ln=$((4*(ln-2)+1))
    [ "$ln" -lt 1 ] && ln=1
    # insert new text
    sed -i "$ln"'i\\' lang_en_$2.txt
    sed -i "$ln"'i\"\x00"\' lang_en_$2.txt
    sed -i "$ln"'i\'"$1"'\' lang_en_$2.txt
    sed -i "${ln}i\\#$3" lang_en_$2.txt
}

# find the metadata for the specified string
# TODO: this is unbeliveably crude
# $1 - text to search for
find_metadata()
{
    sed -ne "s^.*\(_[iI]\|ISTR\)($1).*////\(.*\)^\2^p" ../Firmware/*.[ch]* | head -1
}

# check if input file exists
if ! [ -e lang_add.txt ]; then
    echo "$(tput setaf 1)file lang_add.txt not found"
    exit 1
fi

cat lang_add.txt | sed 's/^/"/;s/$/"/' | while read new_s; do
    if grep "$new_s" lang_en.txt >/dev/null; then
        echo "$(tput setaf 3)text already exist:"
        echo "$(tput setaf 3)$new_s$(tput sgr0)"
        echo
    else
        meta=$(find_metadata "$new_s")
        if [ -z "$meta" ]; then
            echo "$(tput setaf 1)No meta data found for $(tput setaf 3)$new_s$(tput sgr0)"
        fi
        echo "$(tput setaf 2)adding text:"
        echo "$new_s ($meta)$(tput sgr0)"
        echo
        check_en "$new_s" "$meta"
        if [ $skip_insert = "0" ]; then
            insert_en "$new_s" "$meta"
        fi
        for lang in $LANGUAGES; do
            check_xx "$new_s" "$lang" "$meta"
            if [ $skip_insert = "0" ]; then
                insert_xx "$new_s" "$lang" "$meta"
            fi
        done
    fi
done

read -t 5
exit 0
