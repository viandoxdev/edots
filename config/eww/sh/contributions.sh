#!/bin/bash

query="$1"
query_month="$(date -u -d"$query" +%Y%m)"
current_month="$(date -u +%Y%m)"
# user's account's creation date
user_date="$(~/dots/config/eww/sh/github.sh user_info | jq -r '.createdAt')"
user_year="$(date -d "$user_date" +%Y)";
user_month="$(date -d "$user_date" +%m)";

# $1 is a YYYY-MM-DD date

log() {
	echo "$@" >&2
}

send() {
	eww update gh-ctrb-day-data="$(jq -c --arg query "$query" 'map(select(.date | split("T")[0] == $query)) | {data: ., length: length}' < <(cat -))"
}

# update the currently cached files, returns 0 if updated
# 1 if already up to date.
update() {
	log 'update if necesary'
	log ''

	i="${user_year}${user_month}" # YYYYMM

	# find if any month is missing from cache
	missing="false"
	while ! [ "$i" = "$(date +%Y%m)" ]; do
		log "checking for $i"
		if ! [ -f "$HOME/.cache/dots/github/months/$i.json" ]; then
			log "found missing: $i"
			missing="true"
			break
		fi
		i="$(date -d"${i}01 + 1 month" +%Y%m)" # increment i by 1 month
	done

	log ''

	# 1 or more month missing, we requery them all
	if $missing; then
		log "querying all"
		~/dots/config/eww/sh/ghdata.sh all
	fi

	# file is more than 10 min old
	if [ "$(find "/tmp/dots_github_$current_month.json" -mmin +10 2>/dev/null)" ] || ! [ -f "/tmp/dots_github_$current_month.json" ]; then
		log 'current file is outdated / missing, updating'
		~/dots/config/eww/sh/ghdata.sh month > "/tmp/dots_github_$current_month.json"

		return 0
	fi

	log ''

	if $missing; then
		return 0
	fi

	return 1
}

run() {
	# if we're asked for a month that is either before the account's creation or in the future, just return nothing.
	if [ "$query_month" -lt "$user_month" ] || [ "$query_month" -gt "$current_month" ]; then
		log "month isn't covered in data set"
		jq -c < '[]'
		exit 0
	fi

	# the file month with the correct data in it.
	file=""
	if [ "$query_month" = "$current_month" ]; then
		log "month is now"
		file="/tmp/dots_github_$current_month.json"
	else
		log "month is in archive"
		file="$HOME/.cache/dots/github/months/$query_month.json"
	fi

	# check if file exists
	if [ -f "$file" ]; then
		log 'sending current data'
		# send current_version to have something to display
		send < "$file"
	fi

	if update; then # may take a long time
		log 'sending updated data'
		# something changed, re-send
		send < "$file"
	fi
}

if [ "$2" == "-v" ] || [ "$2" == "--verbose" ]; then
	run "$1"
else
	run "$1" 2>/dev/null
fi
