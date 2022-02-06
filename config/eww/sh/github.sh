#!/bin/bash

user="$(~/dots/inf.sh github_graphql_user)"
token="$(~/dots/inf.sh github_graphql_token)"

req() {
	cat - | jq -s -R '{query: .}' |			\
		curl -s -u "$user":"$token" -X POST	\
		-H "Content-Type: application/json"	\
		-d @- 					\
		https://api.github.com/graphql
}


run() {
	case "$1" in
		"avatar")
			if ! [ -f ~/dots/github_pfp.png ]; then
				curl -s "$({ req <<- END
					query {
						viewer {
							avatarUrl(size: 512)
						}
					}
					END
				} | jq '.data.viewer.avatarUrl' -r)" -o ~/dots/github_pfp.png
			fi
			echo "$HOME/dots/github_pfp.png"
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
			{ req <<- END
				query {
	 				viewer {
		 				name
						login
						email
		 			}
	 			}
				END
			} | jq '.data.viewer'
			;;
		"rate")
			 { req <<- END
				query {
					rateLimit {
					  limit
					  remaining
					  resetAt
					}
				}
				END
			 } | jq '.data.rateLimit'
			 ;;
		*)
			;;
	esac
}

[ -z "$1" ] && return 1

if [ "$1" = "--raw" ] || [ "$1" = "-r" ]; then
		  [ -z "$2" ] && return 1
		  # disgusting
		  run "$2" | jq -r 
elif [ "$2" = "--raw" ] || [ "$2" = "-r" ]; then
		  run "$1" | jq -r
else
		  run "$1" 
fi

# vi: set ts=3
