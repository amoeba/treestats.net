#!/bin/sh

set -e 
set -u 

HOST="github.com"
SSH_PATH="$HOME/.ssh"
BRANCH="filtered"

# Set up SSH
# Copied from github.com/maddox/actions
mkdir -p "$SSH_PATH"
touch "$SSH_PATH/known_hosts"
echo "$SSH" > "$SSH_PATH/deploy_key"
chmod 700 "$SSH_PATH"
chmod 600 "$SSH_PATH/known_hosts"
chmod 600 "$SSH_PATH/deploy_key"
eval $(ssh-agent)
ssh-add "$SSH_PATH/deploy_key"
ssh-keyscan -t rsa $HOST >> "$SSH_PATH/known_hosts"

# Do the deploy
git branch "$BRANCH" && \
  git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption_helper.rb' -f "$BRANCH" && \
  git push --force git@github.com:amoeba/treestats.net.git $BRANCH:master && \
  git branch -D $BRANCH