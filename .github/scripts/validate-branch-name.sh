#!/bin/sh

branch=${1:-}

if [ -z "$branch" ]; then
	echo "Branch name is required."
	exit 1
fi

if [ "$branch" = "main" ]; then
	exit 0
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
