#!/bin/sh

branch=${1:-}
scope=${2:-repository}

if [ -z "$branch" ]; then
	echo "Branch name is required."
	exit 1
fi

if [ "$branch" = "main" ]; then
	exit 0
fi

if [ "$scope" = "fork" ]; then
	if printf '%s\n' "$branch" | grep -Eq '^[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9._-]*$'; then
		exit 0
	fi
	echo "Invalid fork branch name: $branch"
	echo "Use the form namespace/description, for example webbrain/issue-74."
	exit 1
fi

case "$branch" in
	feat/*|fix/*|docs/*|chore/*|refactor/*|test/*|ci/*|perf/*|revert/*)
		exit 0
		;;
	*)
		echo "Invalid branch name: $branch"
		echo "Use one of: feat/, fix/, docs/, chore/, refactor/, test/, ci/, perf/, revert/."
		exit 1
		;;
esac
