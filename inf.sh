#!/bin/bash

# this script is used to parse and query data from the info file.

declare -A FIELDS
declare -A DOC

FIELDS[github_graphql_token]="token-goes-here"
DOC[github_graphql_token]="see https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token, needs user and notification access"

FIELDS[github_graphql_user]="your-github-username"

MAX_LENGTH=80 # to limit doc entries width

if ! [ -f "$HOME/dots/info" ]; then
	{
		echo "# edots config file"
		echo ""
		echo "# to put things that can be customized or api token that shouldn't be online."
		echo "# format:"
		echo "# key/value pairs, colon separated. (The colon MUST immediately follow the key)"
		echo "# ie."
		echo "# key: value"
		echo "# Comments useally begin with #, but any line that doesn't follow the above"
		echo "# syntax, or with an invalid key will be effectively treated as a comment."
		echo ""
		
		for key in "${!FIELDS[@]}"; do
			if [ ${DOC["$key"]+_} ]; then # there is documentation for this field
				doc=${DOC["$key"]}
				echo -n "# " # begin comment
				# split newline every MAX_LENGTH characters
				# minus 2 because of the length of "# "
				# shellcheck disable=SC2001
				sed -e 's/.\{'"$((MAX_LENGTH - 2))"'\}/&\n# /g' <<< "$doc"
			fi
			echo "$key:	${FIELDS["$key"]}"
			echo ""
		done
	} > ~/dots/info
fi

# gets the value of a field
# exit code:
# 0 - ok.
# 1 - no such field.
# 2 - unspecified in config, using default value.
query() {
	if ! [ -v 'FIELDS[$1]' ]; then
		return 1
	fi

	# Run awk and store result in res, while keeping trailing new space.
	# This is done to differentiate between there beeing no match (where
	# awk prints nothing) and an empty match (where awk prints a newline).
	IFS= read -rd '' res < <(awk '/^'"$1"':/ {print $2}' < ~/dots/info)

	if [ -z "$res" ]; then # if res is EMPTY (!= blank)
		# print default value
		echo "${FIELDS["$1"]}"
		return 2
	fi

	# remove trailing new lines and print last occurence
	# shellcheck disable=SC2005,SC2116
	tail -n1 <<< "$(echo "$res")"
	return 0
}

# update a field in info
# exit code:
# 0 - ok.
# 1 - no such field.
update() {
	if ! [ -v 'FIELDS[$1]' ]; then
		return 1
	fi

	last_match="$(awk '/^'"$1"':/ {n=NR} END{print n}' < ~/dots/info)"
	last_value="$(awk '/^'"$1"':/ {v=$2} END{print v}' < ~/dots/info)"

	[ "$last_value" = "$2" ] && return 0

	if [ -z "$last_match" ]; then
		{
			echo "[AUTO]"
			echo "$1:	$2"
		} >> ~/dots/info
	else 
		auto=""
		if [ "$last_match" -gt "0" ] && [[ "$(head -n"$((last_match - 1))" < ~/dots/info | tail -n1)" == \[AUTO\]* ]]; then
			auto="auto"
		fi

		top=$(mktemp)
		bottom=$(mktemp)

		head -n"$((last_match - 1))" < ~/dots/info > "$top"
		tail -n +"$((last_match + 1))" < ~/dots/info > "$bottom"

		{
			cat "$top"
			if [ -z "$auto" ]; then
				if [ "$last_value" = "${FIELDS["$1"]}" ]; then
					echo "[AUTO]"
				else 
					echo "[AUTO] # was '$last_value'"
				fi
			fi
			echo "$1:	$2"
			cat "$bottom"
		} > ~/dots/info

		rm "$top"
		rm "$bottom"
	fi
}

if [ -n "$1" ]; then
	if [ "$1" = "-w" ] || [ "$1" = "--write" ]; then
		update "$2" "$3"
	else
		query "$1"
	fi
fi
