#!/bin/sh

set -e 
set -u 

BRANCH="filtered"

git branch "$BRANCH" && \
  git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption_helper.rb' -f "$BRANCH" && \
  git push --force github-public $BRANCH:master && \
  git branch -D $BRANCH