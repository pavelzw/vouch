#!/usr/bin/env nu

use github.nu
use lib.nu [
  add-user
  check-user
  default-vouched-file
  denounce-user
  open-vouched-file
]

# Add a user to the vouched contributors list.
#
# This adds the user to the vouched list, removing any existing entry
# (vouched or denounced) for that user first.
#
# Examples:
#
#   # Preview new file contents (default)
#   ./vouch.nu add someuser
#
#   # Write the file in-place
#   ./vouch.nu add someuser --write
#
#   # Add with platform prefix
#   ./vouch.nu add github:someuser --write
#
export def add [
  username: string,          # Username to vouch for (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
  --vouched-file: string,    # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --write (-w),              # Write the file in-place (default: output to stdout)
] {
  let file = if ($vouched_file | is-empty) {
    let default = default-vouched-file
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  let content = open $file
  let lines = $content | lines
  let comments = $lines | where { |line| ($line | str starts-with "#") or ($line | str trim | is-empty) }
  let contributors = $lines
    | where { |line| not (($line | str starts-with "#") or ($line | str trim | is-empty)) }

  let new_contributors = add-user $username $contributors --default-platform $default_platform
  let new_content = ($comments | append $new_contributors | str join "\n") + "\n"

  if $write {
    $new_content | save -f $file
    print $"Added ($username) to vouched contributors"
  } else {
    print -n $new_content
  }
}

# Check a user's vouch status.
#
# This checks if a user is vouched, denounced, or unknown.
#
# Exit codes:
#   0 - vouched
#   1 - denounced
#   2 - unknown
#
# Examples:
#
#   ./vouch.nu check someuser
#   ./vouch.nu check github:someuser
#
export def check [
  username: string,          # Username to check (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
  --vouched-file: string,    # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
] {
  let file = if ($vouched_file | is-empty) {
    let default = default-vouched-file
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  let lines = open-vouched-file $file
  let status = check-user $username $lines --default-platform $default_platform

  match $status {
    "vouched" => {
      print $"($username) is vouched"
      exit 0
    }
    "denounced" => {
      print $"($username) is denounced"
      exit 1
    }
    _ => {
      print $"($username) is unknown"
      exit 2
    }
  }
}

# Denounce a user by adding them to the VOUCHED file with a minus prefix.
#
# This removes any existing entry for the user and adds them as denounced.
# An optional reason can be provided which will be added after the username.
#
# Examples:
#
#   # Preview new file contents (default)
#   ./vouch.nu denounce badactor
#
#   # Denounce with a reason
#   ./vouch.nu denounce badactor --reason "Submitted AI slop"
#
#   # Write the file in-place
#   ./vouch.nu denounce badactor --write
#
#   # Denounce with platform prefix
#   ./vouch.nu denounce github:badactor --write
#
export def denounce [
  username: string,          # Username to denounce (supports platform:user format)
  --default-platform: string = "", # Assumed platform for entries without explicit platform
  --reason: string,          # Optional reason for denouncement
  --vouched-file: string,    # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --write (-w),              # Write the file in-place (default: output to stdout)
] {
  let file = if ($vouched_file | is-empty) {
    let default = default-vouched-file
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  let content = open $file
  let lines = $content | lines
  let comments = $lines | where { |line| ($line | str starts-with "#") or ($line | str trim | is-empty) }
  let contributors = $lines
    | where { |line| not (($line | str starts-with "#") or ($line | str trim | is-empty)) }

  let new_contributors = denounce-user $username ($reason | default "") $contributors --default-platform $default_platform
  let new_content = ($comments | append $new_contributors | str join "\n") + "\n"

  if $write {
    $new_content | save -f $file
    print $"Denounced ($username)"
  } else {
    print -n $new_content
  }
}

# Check if a PR author is a vouched contributor.
#
# This checks if the PR author is:
#   1. A bot (ends with [bot])
#   2. A collaborator with write access
#   3. In the vouched contributors list
#   4. Denounced
#
# When --require-vouch is true (default), unvouched users are blocked.
# When --require-vouch is false, only denounced users are blocked.
#
# When --auto-close is true and user is unvouched/denounced, the PR is closed.
#
# Outputs status: "skipped" (bot), "vouched", "allowed", or "closed".
#
# Examples:
#
#   # Check PR author status (dry run)
#   ./vouch.nu gh-check-pr 123
#
#   # Auto-close unvouched PRs
#   ./vouch.nu gh-check-pr 123 --auto-close --dry-run=false
#
#   # Allow unvouched users, only block denounced
#   ./vouch.nu gh-check-pr 123 --require-vouch=false --auto-close
#
export def gh-check-pr [
  pr_number: int,              # GitHub PR number
  --repo (-R): string,         # Repository in "owner/repo" format (required)
  --vouched-file: string = ".github/VOUCHED.td", # Path to vouched contributors file in the repo
  --require-vouch = true,      # Require users to be vouched (false = only block denounced)
  --auto-close = false,        # Automatically close PRs from unvouched/denounced users
  --dry-run = true,            # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let owner = ($repo | split row "/" | first)
  let repo_name = ($repo | split row "/" | last)

  let pr_data = github api "get" $"/repos/($owner)/($repo_name)/pulls/($pr_number)"
  let pr_author = $pr_data.user.login
  let default_branch = $pr_data.base.repo.default_branch

  if ($pr_author | str ends-with "[bot]") {
    print $"($pr_author) is a bot, skipping"
    print "skipped"
    return
  }

  let permission = try {
    github api "get" $"/repos/($owner)/($repo_name)/collaborators/($pr_author)/permission" | get permission
  } catch {
    null
  }

  if $permission in ["admin", "write"] {
    print $"($pr_author) is a collaborator with ($permission) access"
    print "vouched"
    return
  }

  let file_data = github api "get" $"/repos/($owner)/($repo_name)/contents/($vouched_file)?ref=($default_branch)"
  let content = $file_data.content | decode base64 | decode utf-8
  let lines = $content | lines
  let status = check-user $pr_author $lines --default-platform github

  if $status == "vouched" {
    print $"($pr_author) is in the vouched contributors list"
    print "vouched"
    return
  }

  if $status == "denounced" {
    print $"($pr_author) is denounced"

    if not $auto_close {
      print "closed"
      return
    }

    print "Closing PR"

    let message = "This PR has been automatically closed because the author has been denounced."

    if $dry_run {
      print "(dry-run) Would post comment and close PR"
      print "closed"
      return
    }

    github api "post" $"/repos/($owner)/($repo_name)/issues/($pr_number)/comments" {
      body: $message
    }

    github api "patch" $"/repos/($owner)/($repo_name)/pulls/($pr_number)" {
      state: "closed"
    }

    print "closed"
    return
  }

  print $"($pr_author) is not vouched"

  if not $require_vouch {
    print $"($pr_author) is allowed \(vouch not required\)"
    print "allowed"
    return
  }

  if not $auto_close {
    print "closed"
    return
  }

  print "Closing PR"

  let message = $"Hi @($pr_author), thanks for your interest in contributing!

We ask new contributors to open an issue first before submitting a PR. This helps us discuss the approach and avoid wasted effort.

**Next steps:**
1. Open an issue describing what you want to change and why \(keep it concise, write in your human voice, AI slop will be closed\)
2. Once a maintainer vouches for you with `lgtm`, you'll be added to the vouched contributors list
3. Then you can submit your PR

This PR will be closed automatically. See https://github.com/($owner)/($repo_name)/blob/($default_branch)/CONTRIBUTING.md for more details."

  if $dry_run {
    print "(dry-run) Would post comment and close PR"
    print "closed"
    return
  }

  github api "post" $"/repos/($owner)/($repo_name)/issues/($pr_number)/comments" {
    body: $message
  }

  github api "patch" $"/repos/($owner)/($repo_name)/pulls/($pr_number)" {
    state: "closed"
  }

  print "closed"
}

# Manage contributor status via issue comments.
#
# This checks if a comment matches "lgtm" (vouch) or "denounce" (denounce),
# verifies the commenter has write access, and updates the vouched list accordingly.
#
# For denounce, the comment can be:
#   - "denounce" - denounces the issue author
#   - "denounce username" - denounces the specified user
#   - "denounce username reason" - denounces with a reason
#
# Outputs a status to stdout: "vouched", "denounced", or "unchanged"
#
# Examples:
#
#   # Dry run (default) - see what would happen
#   ./vouch.nu gh-manage-by-issue 123 456789
#
#   # Actually perform the action
#   ./vouch.nu gh-manage-by-issue 123 456789 --dry-run=false
#
export def gh-manage-by-issue [
  issue_id: int,           # GitHub issue number
  comment_id: int,         # GitHub comment ID
  --repo (-R): string,     # Repository in "owner/repo" format (required)
  --vouched-file: string,  # Path to vouched contributors file (default: VOUCHED.td or .github/VOUCHED.td)
  --allow-vouch = true,   # Enable "lgtm" handling to vouch for contributors
  --allow-denounce = true, # Enable "denounce" handling to denounce users
  --dry-run = true,        # Print what would happen without making changes
] {
  if ($repo | is-empty) {
    error make { msg: "--repo is required" }
  }

  let file = if ($vouched_file | is-empty) {
    let default = default-vouched-file
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  let owner = ($repo | split row "/" | first)
  let repo_name = ($repo | split row "/" | last)
  let issue_data = github api "get" $"/repos/($owner)/($repo_name)/issues/($issue_id)"
  let comment_data = github api "get" $"/repos/($owner)/($repo_name)/issues/comments/($comment_id)"

  let issue_author = $issue_data.user.login
  let commenter = $comment_data.user.login
  let comment_body = ($comment_data.body | default "" | str trim)

  let is_lgtm = $allow_vouch and ($comment_body | parse -r '(?i)^\s*lgtm\b' | is-not-empty)
  let denounce_match = if $allow_denounce {
    $comment_body | parse -r '(?i)^\s*denounce(?:\s+(\S+))?(?:\s+(.+))?$'
  } else {
    []
  }
  let is_denounce = ($denounce_match | is-not-empty)

  if not $is_lgtm and not $is_denounce {
    print "Comment does not match any enabled action"
    print "unchanged"
    return
  }

  let permission = try {
    github api "get" $"/repos/($owner)/($repo_name)/collaborators/($commenter)/permission" | get permission
  } catch {
    print $"($commenter) does not have collaborator access"
    print "unchanged"
    return
  }

  if not ($permission in ["admin", "write"]) {
    print $"($commenter) does not have write access"
    print "unchanged"
    return
  }

  let lines = open-vouched-file $file

  if $is_lgtm {
    let status = check-user $issue_author $lines --default-platform github
    if $status == "vouched" {
      print $"($issue_author) is already vouched"

      if not $dry_run {
        github api "post" $"/repos/($owner)/($repo_name)/issues/($issue_id)/comments" {
          body: $"@($issue_author) is already in the vouched contributors list."
        }
      } else {
        print "(dry-run) Would post 'already vouched' comment"
      }

      print "unchanged"
      return
    }

    if $dry_run {
      print $"(dry-run) Would add ($issue_author) to ($file)"
      print "vouched"
      return
    }

    let new_lines = add-user $issue_author $lines --default-platform github
    let new_content = ($new_lines | str join "\n") + "\n"
    $new_content | save -f $file

    print $"Added ($issue_author) to vouched contributors"
    print "vouched"
    return
  }

  if $is_denounce {
    let match = $denounce_match | first
    let target_user = if ($match.capture0? | default "" | is-empty) {
      $issue_author
    } else {
      $match.capture0
    }
    let reason = $match.capture1? | default ""

    let status = check-user $target_user $lines --default-platform github
    if $status == "denounced" {
      print $"($target_user) is already denounced"
      print "unchanged"
      return
    }

    if $dry_run {
      let entry = if ($reason | is-empty) { $"-($target_user)" } else { $"-($target_user) ($reason)" }
      print $"(dry-run) Would add ($entry) to ($file)"
      print "denounced"
      return
    }

    let new_lines = denounce-user $target_user $reason $lines --default-platform github
    let new_content = ($new_lines | str join "\n") + "\n"
    $new_content | save -f $file

    print $"Denounced ($target_user)"
    print "denounced"
    return
  }
}
