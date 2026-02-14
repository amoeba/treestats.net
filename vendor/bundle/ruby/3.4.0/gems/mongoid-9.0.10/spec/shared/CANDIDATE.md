# Candidate Tasks

When using the `candidate` rake tasks, you must make sure:

1. You are using at least `git` version 2.49.0.
2. You have the `gh` CLI tool installed.
3. You are logged into `gh` with an account that has collaborator access to the repository.
4. You have run `gh repo set-default` from the root of your local checkout to set the default repository to the canonical MongoDB repo.
5. The `origin` remote for your local checkout is set to your own fork.
6. The `upstream` remote for your local checkout is set to the canonical
   MongoDB repo.

Once configured, you can use the following commands:

1. `rake candidate:prs` - This will list all pull requests that will be included in the next release. Any with `[?]` are unlabelled (or are not labelled with a recognized label). Otherwise, `[b]` means `bug`, `[f]` means `feature`, and `[x]` means `bcbreak`.
2. `rake candidate:preview` - This will generate and display the release notes for the next release, based on the associated pull requests.
3. `rake candidate:create` - This will create a new PR against the default repository, using the generated release notes as the description. The new PR will be given the `release-candidate` label.

Then, after the release candidate PR is approved and merged, the release process will automatically bundle, sign, and release the new version.

Once you've merged the PR, you can switch to the "Actions" tab for the repository on GitHub and look for the "Release" workflow (might be named differently), which should have triggered automatically. You can monitor the progress of the release there. If there are any problems, the workflow is generally safe to re-run after you've addressed them.

Things to do after the release succeeds:

1. Copy the release notes from the PR and create a new release announcement on the forums (https://www.mongodb.com/community/forums/c/announcements/driver-releases/110).
2. If the release was not automatically announced in #ruby, copy a link to the GitHub release or MongoDB forum post there.
3. Close the release in Jira.

