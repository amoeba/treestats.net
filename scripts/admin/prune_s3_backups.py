#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "boto3",
#     "botocore[crt]",
# ]
# ///
"""
Prune S3 backups in treestats-backups.

Retention policy:
- For each backup type (mongo, redis, etc.), keep every backup from the last N days.
- For backups older than that, keep the oldest backup of each month.

Run without --execute first to see the dry-run plan.
"""

import argparse
import re
from collections import defaultdict
from datetime import datetime, timedelta, timezone

import boto3

BUCKET = "treestats-backups"
# Match backups like:
# - redis-redis-2026-07-31-04-00-05.tgz
# - mongo-mongo-2026-03-10-04-00-51.tgz
DATE_RE = re.compile(r"(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})\.tgz$")


def get_bucket_usage():
    client = boto3.client("s3")
    paginator = client.get_paginator("list_objects_v2")
    total_size = 0
    total_objects = 0
    for page in paginator.paginate(Bucket=BUCKET):
        for obj in page.get("Contents", []):
            total_size += obj["Size"]
            total_objects += 1
    return total_objects, total_size


def list_objects():
    client = boto3.client("s3")
    paginator = client.get_paginator("list_objects_v2")
    objects = []
    for page in paginator.paginate(Bucket=BUCKET):
        for obj in page.get("Contents", []):
            objects.append((obj["Key"], obj["Size"], obj["LastModified"]))
    return objects


def parse_key(key):
    m = DATE_RE.search(key)
    if not m:
        return None
    dt = datetime.strptime(m.group(1), "%Y-%m-%d-%H-%M-%S")
    return dt.replace(tzinfo=timezone.utc)


def backup_type(key):
    return key.split("-")[0]


def decide_keep(objects, daily_days):
    cutoff = datetime.now(timezone.utc) - timedelta(days=daily_days)

    by_type = defaultdict(list)
    for key, size, last_modified in objects:
        dt = parse_key(key)
        if dt is None:
            continue
        by_type[backup_type(key)].append((key, dt, size))

    keep = set()
    for btype, items in by_type.items():
        items.sort(key=lambda x: x[1])

        # Keep everything within the daily retention window
        for key, dt, size in items:
            if dt >= cutoff:
                keep.add(key)

        # For older backups, keep the oldest backup of each month
        older = [(k, dt, s) for k, dt, s in items if dt < cutoff]
        seen_months = set()
        for key, dt, size in older:
            month = dt.strftime("%Y-%m")
            if month not in seen_months:
                keep.add(key)
                seen_months.add(month)

    return keep


def delete_objects(keys):
    client = boto3.client("s3")
    batch_size = 1000
    total = len(keys)
    for i in range(0, total, batch_size):
        batch = keys[i : i + batch_size]
        response = client.delete_objects(
            Bucket=BUCKET,
            Delete={"Objects": [{"Key": k} for k in batch], "Quiet": False},
        )
        deleted = len(response.get("Deleted", []))
        errors = response.get("Errors", [])
        print(f"  deleted {min(i + deleted, total)} / {total}")
        for err in errors:
            print(f"  ERROR deleting {err['Key']}: {err['Message']}")


def format_usage(objects, size):
    return f"{objects} objects, {size / 1024**3:.2f} GiB"


def main():
    parser = argparse.ArgumentParser(description="Prune old S3 backups")
    parser.add_argument(
        "--daily-days",
        type=int,
        default=14,
        help="Number of recent days to keep daily backups (default: 14)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=True,
        help="Print the pruning plan without deleting anything (default).",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually delete objects. Implies --no-dry-run.",
    )
    parser.add_argument(
        "--save-keep-list",
        metavar="FILE",
        help="Write the list of kept keys to this file",
    )
    args = parser.parse_args()

    print(f"Current bucket usage: {format_usage(*get_bucket_usage())}")
    print(f"\nListing objects in s3://{BUCKET} ...")
    objects = list_objects()
    print(f"Found {len(objects)} objects")

    keep = decide_keep(objects, args.daily_days)
    delete = [key for key, _, _ in objects if key not in keep]

    keep_size = sum(size for key, size, _ in objects if key in keep)
    delete_size = sum(size for key, size, _ in objects if key not in keep)

    print(f"\nRetention: keep daily backups for last {args.daily_days} days")
    print(f"           keep oldest backup of each month for older backups")
    print(f"\nKeep:    {len(keep):4d} objects ({keep_size / 1024**3:.2f} GiB)")
    print(f"Delete:  {len(delete):4d} objects ({delete_size / 1024**3:.2f} GiB)")

    if args.save_keep_list:
        with open(args.save_keep_list, "w") as f:
            for key in sorted(keep):
                f.write(key + "\n")
        print(f"\nWrote keep list to {args.save_keep_list}")

    if not delete:
        print("\nNothing to delete.")
        print(f"Bucket usage after: {format_usage(*get_bucket_usage())}")
        return

    print("\nKept files:")
    for key in sorted(keep):
        print(f"  {key}")

    print("\nDeleted files:")
    for key in sorted(delete):
        print(f"  {key}")

    if args.dry_run and not args.execute:
        print("\nThis is a dry run. Add --execute to delete the listed objects.")
        return

    print(f"\nDeleting {len(delete)} objects...")
    delete_objects(delete)
    print("\nDone.")
    print(f"Bucket usage after: {format_usage(*get_bucket_usage())}")


if __name__ == "__main__":
    main()
