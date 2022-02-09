#!/bin/bash

log() {
	echo "$@" >&2
}

ghsh="$HOME/dots/config/eww/sh/github.sh"
user_year="$(date -d"$($ghsh user_info | jq -r '.createdAt')" +%Y)"

query_year() {

	dir="$(mktemp -d)"

	start_year="$(date -d"01/01/$1" -Is)"
	end_year="$(date -d"01/01/$(($1 + 1))" -Is)"

	log "querying $start_year -> $end_year"
	log ''

	NAMES=("commits" "issues" "pull_requests" "pull_requests_reviews" "repositories")

	mkdir -p "$HOME/dots/cache/github/months"
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
	

	# merge commits/XXXXXX.json issues/XXXXXX.json ... in .../cache/.../XXXXXX.json
	for i in {01..12}; do
		month="${1}${i}"
		inputs=()
		for n in "${NAMES[@]}"; do
			inputs+=("$dir/$n/$month.json")
		done

		jq -nc '[inputs] | flatten | sort_by(.date | fromdateiso8601)' "${inputs[@]}" > "$HOME/dots/cache/github/months/$month.json"
	done

	rm -r "$dir"
}

current_year="$(date -u +%Y)"
current_month="${current_year}$(date -u +%m)" # YYYYMM
year="$((user_year - 1))" # year will be incremented right after

while ! [ "$year" = "$current_year" ]; do
	year=$((year + 1))
	query_year "$year"
done

log 'cleaning up'
log ''

# delete any future months as well as the current_month, because those are subject to change.
for file in "$HOME/dots/cache/github/months/"* ; do
	fmonth="$(cut -d "." -f1 <<< "$(basename "$file")")" # YYYYMM
	# this works because in YYYYMM if DATE1 > DATE2 (numerically),
	# then DATE1 is after DATE2 (time wise)
	if [ "$fmonth" -ge "$current_month" ]; then
		log "deleting $fmonth.json"
		rm "$file"
	fi
done
