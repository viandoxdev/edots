#!/bin/bash

VERBOSE="false"

user="$(~/dots/inf.sh github_graphql_user)"
token="$(~/dots/inf.sh github_graphql_token)"

# shellcheck disable=SC2120
req() {
	query="$(cat -)"
	args="$1"

	# if arg isn't valid json, ignore
	if ! jq -e . <<< "$1" >/dev/null 2>&1; then
		args="{}"
	fi

	$VERBOSE && echo -e "\033[34msending request:\n$query\nargs: $args\033[0m" >&2

	body="$(jq -s -R --argjson args "$args"	'{query: ., variables: $args}' <<< "$query")"

	$VERBOSE && echo "${body}" >&2

	curl -s -u "$user":"$token" -X POST	\
	-H "Content-Type: application/json"	\
	-d "$body"				\
	https://api.github.com/graphql
}
# 1 is endpoint
# 2 is query parameters
# 3 is type
rest-req() {
	uri="https://api.github.com${1}?${2}"
	
	curl -s -u "$user:$token" -X "$3" \
	"$uri"
}

# how many nodes do we want at a time
# max is 100, there really isn't any reason to set it to anything else tbh.
PAGE_AMOUNT=100

# make a request and handle pagination
# 1 [string] - the path to the paginated object (that has pageInfo and nodes fields)
# 2 [string] - json string of arguments meant to be passed to the query, can't contain cursor or amount
# 3 [string] - in case there are not one but an array of paginated objects, 1 becomes the path to the array
#     aand this is the path from an element to the paginated object.
req-page() {
	dir="$(mktemp -d)"
	hasnext="true"
	cursor="null"
	
	args="$2"
	if ! jq -e <<< "$args" >/dev/null 2>&1; then
		args="{}"
	fi
	
	query="$(cat -)"
	
	echo "[]" > "$dir/1.json"
	
	while [ "$hasnext" = "true" ]; do
		$VERBOSE && echo "querying $PAGE_AMOUNT nodes after $cursor" >&2
		reqargs="$(jq -n			\
			--argjson amount "$PAGE_AMOUNT"	\
			--argjson after "$cursor"	\
			--argjson args "$args"		\
			'$args + {amount: $amount, cursor: $after}')"
		res="$(req "$reqargs" <<< "$query" | jq ".data.$1")"

		if [ -z "$3" ]; then # its an array
			hasnext="$(jq -c '.pageInfo.hasNextPage' <<< "$res")"
			cursor="$(jq -c '.pageInfo.endCursor' <<< "$res")"

			# write result in 0.json
			jq -c '.nodes' <<< "$res" > "$dir/0.json"
		else
			hasnext="$(jq -c "map(.$3.pageInfo.hasNextPage) | any" <<< "$res")"
			cursor="$(jq -c "[.[] | select(.$3.pageInfo.hasNextPage)][0].$3.pageInfo.endCursor" <<< "$res")"

			# write result in 0.json
			jq -c "map(.$3.nodes | .[])" <<< "$res" > "$dir/0.json"
		fi
		
		$VERBOSE && echo "got response, cursor: $cursor, next: $hasnext" >&2
		
		# merge 0.json and 1.json (previous results)
		jq -nc '[inputs | .[]]' "$dir/0.json" "$dir/1.json" > "$dir/2.json"
		mv "$dir/2.json" "$dir/1.json"
	done
	jq -c '[.[] | select(. != null)]' < "$dir/1.json"
	rm -r "$dir"
}

case "$1" in
	"avatar")
		mkdir -p ~/.cache/dots/github
		if ! [ -f ~/.cache/dots/github/avatar.png ]; then
			curl -s "$({ req <<- END
				query {
				  viewer {
				    avatarUrl(size: 512)
				  }
				}
				END
			} | jq '.data.viewer.avatarUrl' -r)" -o ~/.cache/dots/github/avatar.png
		fi
		echo "$HOME/.cache/dots/github/avatar.png"
		;;
	"contrib")
		{ req <<- END
			query {
			  viewer {
			    contributionsCollection(to: "$(date -u -dsaturday -Is)") {
			      contributionCalendar {
			        weeks {
			          contributionDays {
			            contributionCount
			            date
			            weekday
			          }
			        }
			      }
			    }
			  }
			}
			END
		} | jq -c '(.data.viewer.contributionsCollection.contributionCalendar.weeks | .[] |= .contributionDays) | {length: length, data: . | reverse}'
		;;
	"user_info")
		# cached in /tmp because it gets automatically destroyed on reboot (if /tmp is a tmpfs)
		if [ -f "/tmp/dots_github_user_info.json" ]; then
			jq -c < "/tmp/dots_github_user_info.json"
		else
			{ req <<- END
				query {
				  viewer {
				    name
				    login
				    email
				    createdAt
				  }
				}
				END
			} | jq '.data.viewer' > "/tmp/dots_github_user_info.json"
			jq -c < "/tmp/dots_github_user_info.json"
		fi
		;;
	"issues")
		from="\"$2\""
		to="\"$3\""
		if [ -z "$2" ]; then from="null"; fi
		if [ -z "$3" ]; then to="null"; fi
		{ req-page 'viewer.contributionsCollection.issueContributions' '{"from": '"$from"', "to": '"$to"'}' <<- END
			query(\$amount: Int!, \$cursor: String, \$from: DateTime, \$to: DateTime) { 
			  viewer {
			    contributionsCollection(from: \$from, to: \$to) {
			      issueContributions(first: \$amount, after: \$cursor) {
			        pageInfo {
			          endCursor
			          hasNextPage
			        }
			        nodes {
			          issue {
			            url
			            publishedAt
			            title
			            number
			            repository {
			              url
			              name
			              owner {
			                login
			                url
			              }
			            }
			          }
			        }
			      }
			    }
			  }
			}
			END
		} | jq -c 'map(.issue | . + {date: .publishedAt} | del(.publishedAt))'
		;;
	"pull_requests")
		from="\"$2\""
		to="\"$3\""
		if [ -z "$2" ]; then from="null"; fi
		if [ -z "$3" ]; then to="null"; fi
		{ req-page 'viewer.contributionsCollection.pullRequestContributions' '{"from": '"$from"', "to": '"$to"'}' <<- END
			query(\$amount: Int!, \$cursor: String, \$from: DateTime, \$to: DateTime) { 
			  viewer {
			    contributionsCollection(from: \$from, to: \$to) {
			      pullRequestContributions(first: \$amount, after: \$cursor) {
			        pageInfo {
			          endCursor
			          hasNextPage
			        }
			        nodes {
			          pullRequest {
			            url
			            publishedAt
			            title
			            number
			            repository {
			              name
			              owner {
			                login
			                url
			              }
			            }
			          }
			        }
			      }
			    }
			  }
			}
			END
		} | jq -c 'map(.pullRequest | . + {date: .publishedAt} | del(.publishedAt))'
		;;
	"pull_requests_reviews")
		from="\"$2\""
		to="\"$3\""
		if [ -z "$2" ]; then from="null"; fi
		if [ -z "$3" ]; then to="null"; fi
		{ req-page 'viewer.contributionsCollection.pullRequestReviewContributions' '{"from": '"$from"', "to": '"$to"'}' <<- END
			query(\$amount: Int!, \$cursor: String, \$from: DateTime, \$to: DateTime) { 
			  viewer {
			    contributionsCollection(from: \$from, to: \$to) {
			      pullRequestReviewContributions(first: \$amount, after: \$cursor) {
			        pageInfo {
			          endCursor
			          hasNextPage
			        }
			        nodes {
			          pullRequestReview {
			            url
			            publishedAt
			            state
			            pullRequest {
			              number
			              url
			              repository {
			                url
			                name
			                owner {
			                  login
			                  url
			                }
			              }
			            }
			          }
			        }
			      }
			    }
			  }
			}
			END
		} | jq -c 'map(.pullRequestReview | . + {date: .publishedAt} | del(.publishedAt))'
		;;
	"commits")
		from="\"$2\""
		to="\"$3\""
		if [ -z "$2" ]; then from="null"; fi
		if [ -z "$3" ]; then to="null"; fi
		{ req-page 'viewer.contributionsCollection.commitContributionsByRepository' '{"from": '"$from"', "to": '"$to"'}' 'contributions' <<- END
			query(\$amount: Int!, \$cursor: String, \$from: DateTime, \$to: DateTime) { 
			  viewer {
			    contributionsCollection(from: \$from, to: \$to) {
			      commitContributionsByRepository {
			        contributions(first: \$amount, after: \$cursor) {
			          pageInfo {
			            endCursor
			            hasNextPage
			          }
			          nodes {
			            commitCount
			            repository {
			              url
			              name
			              owner {
			                login
			              }
			            }
			            occurredAt
			          }
			        }
			      }
			    }
			  }
			}
			END
		} | jq -c 'map(. + {date: .occurredAt} | del(.occurredAt))'
		;;
	"repositories")
		from="\"$2\""
		to="\"$3\""
		if [ -z "$2" ]; then from="null"; fi
		if [ -z "$3" ]; then to="null"; fi
		{ req-page 'viewer.contributionsCollection.repositoryContributions' '{"from": '"$from"', "to": '"$to"'}' <<- END
			query(\$amount: Int!, \$cursor: String, \$from: DateTime, \$to: DateTime) { 
			  viewer {
			    contributionsCollection(from: \$from, to: \$to) {
			      repositoryContributions(first: \$amount, after: \$cursor) {
			        pageInfo {
			          endCursor
			          hasNextPage
			        }
			        nodes {
			          occurredAt
			          repository {
			            url
			            name
				    isFork
			            parent {
			              url
			              name
			              owner {
			                login
			                url
			              }
			            }
			          }
			        }
			      }
			    }
			  }
			}
			END
		} | jq -c 'map(.repository + {date: .occurredAt} | del(.occurredAt))'
		;;
	"rate")
		{ req <<- END
			query {
			  rateLimit {
			    limit
			    remaining
			    used
			    resetAt
			  }
			}
			END
		} | jq '.data.rateLimit'
		;;
	"notifications")
		rest-req "/notifications" "all=true" "GET" | jq 'map({id, unread, reason, subject, repo_url: .repository.html_url, date: .updated_at}) | sort_by(.date | fromdateiso8601) |  reverse | {read: . | map(select(.unread != true)), unread: . | map(select(.unread))}' -c
		;;
	# notifications, but sent to eww by the script
	"eww_notifs")
		(
			eww update gh-notifs="$(~/dots/config/eww/sh/github.sh notifications)"
		) &
		;;
	"read_notif")
		rest-req "/notifications/threads/$2" "" "PATCH"
		~/dots/config/eww/sh/github.sh eww_notifs
		;;
	*)
		;;
esac

# vi: set ts=3
