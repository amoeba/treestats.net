#!/bin/sh

set -e 
set -u 

SSH_PATH="$HOME/.ssh"
BRANCH="filtered"

# Set up SSH
# From https://github.com/maxheld83/rsync/blob/master/entrypoint.sh
printf -- "Giving container SSH abilities..."

mkdir -p "$SSH_PATH"
touch "$SSH_PATH/known_hosts"
echo "$FINGERPRINT" > "$SSH_PATH/known_hosts"

echo "$SSH_PRIVATE_KEY" > "$SSH_PATH/deploy_key"
echo "$SSH_PUBLIC_KEY" > "$SSH_PATH/deploy_key.pub"

chmod 700 "$SSH_PATH"
chmod 600 "$SSH_PATH/known_hosts"
chmod 600 "$SSH_PATH/deploy_key"
chmod 600 "$SSH_PATH/deploy_key.pub"

eval "$(ssh-agent -s)"
ssh-add "$SSH_PATH/deploy_key"

# Do the deploy
printf -- "Filtering..."
git branch "$BRANCH" && \
  git filter-branch --index-filter 'git rm --cached --ignore-unmatch helpers/encryption_helper.rb' -f "$BRANCH" && \
  git push --force git@github.com:amoeba/treestats.net.git $BRANCH:master && \
  git branch -D $BRANCH

printf -- "Done"