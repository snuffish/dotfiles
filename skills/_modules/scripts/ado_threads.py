#!/usr/bin/env python3
"""Print the human comments of an Azure DevOps PR's threads (pr-host-threads.md).

Usage: python3 -I ado_threads.py <threads.json>   (output of `az devops invoke … pullRequestThreads`)
Skips deleted threads, deleted and system comments, and the Azure Pipelines test bot.
"""
import json
import sys

for t in json.load(open(sys.argv[1])).get("value", []):
    if t.get("isDeleted"):
        continue
    ctx = t.get("threadContext") or {}
    line = (ctx.get("rightFileStart") or {}).get("line")
    human = [
        c
        for c in t.get("comments", [])
        if not c.get("isDeleted")
        and c.get("commentType") != "system"
        and c.get("author", {}).get("displayName") != "Azure Pipelines Test Service"
    ]
    if human:
        print(f"=== Thread {t['id']} | {t.get('status')} | {ctx.get('filePath')}:{line} ===")
        for c in human:
            print(f"[{c['author']['displayName']}] ({c.get('publishedDate')}):\n{c.get('content')}\n")
