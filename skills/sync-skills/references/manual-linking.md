# Manual Symlink Loops & Live-State Checks

Use [`../sync_skills.py`](../sync_skills.py) (`/sync-skills`) for normal loader reconciliation. Use the snippets below only when bootstrapping a machine without Python or inspecting symlinks by hand.

## macOS / Linux (Bash/Zsh)

```bash
SKILLS="$PWD"   # run from the skills/ folder

# A single skill:
ln -s "$SKILLS/code-review" ~/.claude/skills/code-review

# Every general skill and every Profile, flattened by name:
for d in "$SKILLS"/*/ "$SKILLS"/Projects/*/*-profile/; do
  [ -f "$d/SKILL.md" ] && ln -sfn "${d%/}" ~/.claude/skills/"$(basename "$d")"
done
```

## Windows (PowerShell)

```powershell
$Skills = (Get-Location).Path   # run from the skills\ folder

# A single skill:
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\skills\code-review" -Value "$Skills\code-review"

# Every general skill and every Profile, flattened by name:
@(Get-ChildItem -Path $Skills -Directory) + @(Get-ChildItem -Path "$Skills\Projects\*\*-profile" -Directory) |
  ForEach-Object { Get-Item (Join-Path $_.FullName "SKILL.md") -ErrorAction SilentlyContinue } | ForEach-Object {
    $srcDir = $_.DirectoryName
    $destDir = Join-Path "$env:USERPROFILE\.claude\skills" $_.Directory.Name
    New-Item -ItemType SymbolicLink -Path $destDir -Value $srcDir -Force
}
```

## Manual Live-State Checks (macOS / Linux)

```bash
find ~/.claude/skills ~/.gemini/config/skills ~/.gemini/skills -maxdepth 1 -xtype l   # dead links: expect none
ls -la ~/.claude/skills | grep -c -- "-> $PWD/"                                       # links into this tree (run from skills/)
```
