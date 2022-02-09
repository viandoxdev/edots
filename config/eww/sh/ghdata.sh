#!/bin/bash

log() {
	echo "$@" >&2
}

ghsh="$HOME/dots/config/eww/sh/github.sh"
# the name of all the kind of contributions (must match in github.sh)
NAMES=("commits" "issues" "pull_requests" "pull_requests_reviews" "repositories")

query_year() {

	dir="$(mktemp -d)"

	start_year="$(date -d"01/01/$1" -Is)"
	end_year="$(date -d"01/01/$(($1 + 1))" -Is)"

	log "querying $start_year -> $end_year"
	log ''

	mkdir -p "$dir/months"
	
	for i in "${!NAMES[@]}"; do
		n="${NAMES[i]}"
		log "processing $n $i/${#NAMES[@]}"
		log "  querying"
		$ghsh "$n" "$start_year" "$end_year" > "$dir/data.json"
		log "  organizing"

		# jq (ab)use: converts objects of form:
		# [
		#   {"date": "2022-02-09T01:23:13+01:00", ...},
		#   {"date": "2022-02-05T05:19:14+05:00", ...},
		#   {"date": "2022-03-04T15:11:14+55:00", ...},
		#   {"date": "2022-01-23T04:20:07+41:00", ...}
		# ]
		# to: (essentialy split by month)
		# {
		#   "202201": [
		#     {"date": "2022-01-23T04:20:07+41:00", "type": $n, ...},
		#   ],
		#   "202202": [
		#     {"date": "2022-02-09T01:23:13+01:00", "type": $n, ...},
		#     {"date": "2022-02-05T05:19:14+05:00", "type": $n, ...},
		#   ],
		#   "202203": [
		#     {"date": "2022-03-04T15:11:14+55:00", "type": $n, ...}
		#   ]
		# }
		jq -c --arg n "$n" 'map({key: .date | split("-") | [.[0], .[1]] | join(""), value: .}) | group_by(.key) | map({key: .[0].key, value:  map(.value + {type: $n})}) | from_entries' < "$dir/data.json" > "$dir/data_months.json"

		mkdir -p "$dir/$n"

		for month in $(jq -r 'to_entries | .[] | .key' < "$dir/data_months.json"); do
			jq '.["'"$month"'"]' > "$dir/$n/$month.json" < "$dir/data_months.json"
		done
	done

	log ""
	log "merging"
	log ""

	# make sure all the months files exists, even if empty.
	for i in {01..12}; do
		month="${1}${i}"
		for n in "${NAMES[@]}"; do
			if ! [ -f "$dir/$n/$month.json" ]; then
				echo "[]" > "$dir/$n/$month.json"
			fi
		done
	done
	
	# dir with resulting files
	res="$(mktemp -d)"
	
	# merge commits/XXXXXX.json issues/XXXXXX.json ... in res/XXXXXX.json
	for i in {01..12}; do
		month="${1}${i}"
		inputs=()
		for n in "${NAMES[@]}"; do
			inputs+=("$dir/$n/$month.json")
		done

		jq -nc '[inputs] | flatten | sort_by(.date | fromdateiso8601)' "${inputs[@]}" > "$res/$month.json"
	done

	rm -r "$dir"

	# return results dir
	echo "$res"
}

query_month() {
	# $1 is a month in YYYYMM format
	date_start="$(date -u -d"${1}01" -Is)"
	date_end="$(date -u -d"${1}01 + 1 month" -Is)"
	dir="$(mktemp -d)"

	log "querying month from $date_start -> $date_end"
	log ''

	# query data from API and put into $name.json 
	for i in "${!NAMES[@]}"; do
		n="${NAMES[i]}"
		log "processing $n $i/${#NAMES[@]}"
		log '  querying'
		$ghsh "$n" "$date_start" "$date_end" > "$dir/data.json"
		log '  organizing'
		jq --arg n "$n" 'map(. + {type: $n})' < "$dir/data.json" > "$dir/$n.json"
	done

	inputs=()
	for n in "${NAMES[@]}"; do
		inputs+=("$dir/$n.json")
	done

	jq -n '[inputs] | flatten | sort_by(.date | fromdateiso8601)' "${inputs[@]}" -c

	rm -r "$dir"
}

query_all() {
	# query all data from $1 to now, aligns on years.

	start_year="$(date -d"$1" +%Y)"
	start_month="$(date -u -d"$1" +%Y%m)"
	# current year in utc
	current_year="$(date -u +%Y)"
	# current date in utc (YYYYMM)
	current_month="$(date -u +%Y%m)" # YYYYMM
	# year variable to count up to now
	year="$((start_year - 1))" # year will be incremented right after

	mkdir -p "$HOME/.cache/dots/github/months"

	while ! [ "$year" = "$current_year" ]; do
		log ''
		year=$((year + 1))
		# res is the path to a folder in /tmp containing the json files representing every month of $year
		res="$(query_year "$year")"

		log 'cleaning up'
		log ''

		# save the months we want to cache, ignoring the months before the account's
		# creation as well as the one after or equal to the current one.
		for file in "$res/"* ; do
			fmonth="$(cut -d "." -f1 <<< "$(basename "$file")")" # YYYYMM of file

			# this works because in YYYYMM if DATE1 > DATE2 (numerically),
			# then DATE1 is after DATE2 (time wise)
			if [ "$fmonth" -ge "$start_month" ] && [ "$fmonth" -lt "$current_month" ]; then
				mv "$file" "$HOME/.cache/dots/github/months/"
			else
				log "ignoring $fmonth"
			fi
		done

		# res is in temp, so we delete it once were done saving what we want
		rm -r "$res"
	done
}

run() {
	# user's account's creation date
	user_date="$($ghsh user_info | jq -r '.createdAt')"
	case "$1" in
		"all")
			query_all "$user_date"
			;;
		"month")
			query_month "$(date -u +%Y%m)"
			;;
		*)
			log 'unknown command'
			;;
	esac
}

if [ "$2" == "-v" ] || [ "$2" == "--verbose" ]; then
	run "$1"
else
	run "$1" 2>/dev/null
fi
