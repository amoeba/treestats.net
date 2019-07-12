#!/bin/sh

set -e

change_branch=$(git branch filtered)
echo $change_branch

filter_branch=$(git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption_helper.rb' -f filtered)
echo $filter_branch

git_push=$(git push --force github-public filtered:master)
echo $git_push

delete_branch=$(git branch -D filtered)
echo $delete_branch
