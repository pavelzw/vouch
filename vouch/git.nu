# Non-forge-specific git operations

# Commit and push changes to a vouched file.
#
# Configures git authorship as github-actions[bot], stages the file,
# and pushes. If there are no changes to commit, this is a no-op.
export def commit-and-push [
  file: string,              # Path to the vouched file
  --message: string = "",    # Commit message (default: "Update VOUCHED list")
] {
  # New files aren't tracked yet, so `git diff` won't see them.
  # Stage first so the diff check below covers both new and
  # modified files.
  let is_new = (
    git ls-files $file | str trim | is-empty
  )
  if $is_new {
    git add $file
  }

  # Exit early when the file hasn't actually changed to avoid
  # creating empty commits.
  let diff = git diff --quiet $file | complete
  if $diff.exit_code == 0 and not $is_new {
    return
  }

  # Configure authorship for the commit. We use the GitHub Actions
  # bot identity so the commit is attributed to the automation
  # rather than a human.
  git config user.name "github-actions[bot]"
  git config user.email (
    "41898282+github-actions[bot]@users.noreply.github.com"
  )
  git add $file
  git commit -m ($message | default -e "Update VOUCHED list")
  git push
}
