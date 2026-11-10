# News publishing

News is stored in MongoDB's `news_posts` collection. There is no static-content
fallback: after deployment, news stays empty until an admin publishes a post or
an operator imports the historical entries.

## Administration

1. Sign in using the existing admin login, then open **Admin → News**.
2. Choose **Create news post**. Enter a title and Markdown body.
3. **Preview** renders the unsaved body using the same renderer as the public
   page. Preview keeps your fields in the editor and does not save anything.
4. **Save draft** keeps the post private. **Publish** makes it public immediately.
5. **Save changes** on a published post takes effect immediately; there is no
   separate revision/approval workflow.
6. **Unpublish to draft** hides a post from the homepage, archive and its public
   URL. Republishing uses the same URL. There is deliberately no delete action.

Public posts show only the title, publication date, and body, without an author
byline. Markdown supports paragraphs, links, emphasis, lists and code. Raw HTML is escaped and rendered output is
sanitized, including link protocols. Preview and public rendering use the same
safety rules.

### Dates and URLs

- Publication inputs are explicitly **UTC**, independent of the browser timezone.
- Leave the date blank when publishing to use the current time. Backdating is
  supported. Future dates are rejected: there is no automatic scheduling.
- Editing preserves the existing publication date unless explicitly changed.
- A readable slug is assigned at first publication and stays stable after title
  changes, unpublishing and republishing. Duplicate titles get a unique suffix.
- Public lists are ordered by publication date, newest first (then ID for ties).
  The homepage shows the latest five titles alongside compact UTC dates (hover
  for the full timestamp); `/news` shows 20 posts per page.
- Draft and unknown URLs return 404. Management pages are admin-only, no-store,
  and excluded from indexing; writes and previews require CSRF tokens.

## Importing historical posts (operator action)

The 17 former homepage updates are preserved as Markdown in
`data/legacy_news.json`, with their original UTC dates and generated titles for
previously untitled entries. They are **not imported automatically**, including
on deployment, startup, or test execution. Import-writing tests use synthetic
fixtures only.

From the repository root, with the app's dependencies and MongoDB/Redis available:

```sh
# Default: validate and report only; writes neither posts nor indexes.
bundle exec ruby scripts/admin/import-news.rb --dry-run

# Explicitly import into the development database.
bundle exec ruby scripts/admin/import-news.rb --apply
```

For production, run in the deployed application's environment (with `MONGO_URL`,
`REDIS_URL`, `SESSION_SECRET`, and other normal application settings configured):

```sh
RACK_ENV=production bundle exec ruby scripts/admin/import-news.rb --dry-run
RACK_ENV=production bundle exec ruby scripts/admin/import-news.rb --apply
```

Check the target environment printed by the script before applying. Take the
usual database backup first. The script validates the complete input before
writing, creates the news indexes, then imports entries as published posts.
An interrupted import can be rerun: unique `legacy_id` values prevent duplicates,
and previously imported entries are skipped without overwriting admin edits or
republishing entries that were subsequently unpublished. It does not delete or
replace any existing news.

`--file PATH` selects an alternative JSON array with the same fields:
`legacy_id`, `title`, `body`, and an ISO 8601 UTC `published_at` ending in `Z`.
The importer reports validation failures with a nonzero exit status. Database
failures can leave a partially completed import; rerun after resolving the error.

## Indexes

The model declares unique partial indexes on `slug` and `legacy_id` (so multiple
unpublished drafts are allowed) and a compound publication-order index. These
are ensured on post creation and by an applied import; the dry run creates none.
If provisioning indexes separately, use the app's usual Mongoid index task or
`NewsPost.ensure_indexes!` in the configured application environment.
