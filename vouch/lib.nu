# Library functions for vouch contributor management.

# Check a user's status in contributor lines.
#
# Filters out comments and blank lines before checking.
# Supports platform:username format (e.g., github:mitchellh).
# Returns "vouched", "denounced", or "unknown".
export def check-user [
  username: string,            # Username to check (supports platform:user format)
  lines: list<string>,         # Lines from the vouched file
  --default-platform: string = "", # Assumed platform for entries without explicit platform
] {
  let contributors = $lines
    | where { |line| not (($line | str starts-with "#") or ($line | str trim | is-empty)) }

  let parsed_input = parse-handle $username
  let input_user = $parsed_input.username
  let input_platform = $parsed_input.platform
  let default_platform_lower = ($default_platform | str downcase)

  for line in $contributors {
    let handle = ($line | str trim | split row " " | first)
    
    let is_denounced = ($handle | str starts-with "-")
    let entry = if $is_denounced { $handle | str substring 1.. } else { $handle }
    
    let parsed = parse-handle $entry
    let entry_platform = if ($parsed.platform | is-empty) { $default_platform_lower } else { $parsed.platform }
    let entry_user = $parsed.username
    
    let check_platform = if ($input_platform | is-empty) { $default_platform_lower } else { $input_platform }
    
    let platform_matches = ($check_platform | is-empty) or ($entry_platform | is-empty) or ($entry_platform == $check_platform)
    
    if ($entry_user == $input_user) and $platform_matches {
      if $is_denounced {
        return "denounced"
      } else {
        return "vouched"
      }
    }
  }

  "unknown"
}

# Add a user to the contributor lines, removing any existing entry first.
# Comments and blank lines are ignored and preserved.
#
# Supports platform:username format (e.g., github:mitchellh).
#
# Returns the updated lines with the user added and sorted.
export def add-user [
  username: string,            # Username to add (supports platform:user format)
  lines: list<string>,         # Lines from the vouched file
  --default-platform: string = "", # Assumed platform for entries without explicit platform
] {
  let filtered = remove-user $username $lines --default-platform $default_platform
  $filtered | append $username | sort -i
}

# Denounce a user in the contributor lines, removing any existing entry first.
#
# Supports platform:username format (e.g., github:mitchellh).
# Returns the updated lines with the user added as denounced and sorted.
export def denounce-user [
  username: string,            # Username to denounce (supports platform:user format)
  reason: string,              # Reason for denouncement (can be empty)
  lines: list<string>,         # Lines from the vouched file
  --default-platform: string = "", # Assumed platform for entries without explicit platform
] {
  let filtered = remove-user $username $lines --default-platform $default_platform
  let entry = if ($reason | is-empty) { $"-($username)" } else { $"-($username) ($reason)" }
  $filtered | append $entry | sort -i
}

# Remove a user from the contributor lines (whether vouched or denounced).
# Comments and blank lines are ignored (passed through unchanged).
#
# Supports platform:username format (e.g., github:mitchellh).
# Returns the filtered lines after removal.
export def remove-user [
  username: string,            # Username to remove (supports platform:user format)
  lines: list<string>,         # Lines from the vouched file
  --default-platform: string = "", # Assumed platform for entries without explicit platform
] {
  let parsed_input = parse-handle $username
  let input_user = $parsed_input.username
  let input_platform = $parsed_input.platform
  let default_platform_lower = ($default_platform | str downcase)

  $lines | where { |line|
    if ($line | str starts-with "#") or ($line | str trim | is-empty) {
      return true
    }

    let handle = ($line | split row " " | first)
    let entry = if ($handle | str starts-with "-") {
      $handle | str substring 1..
    } else {
      $handle
    }

    let parsed = parse-handle $entry
    let entry_platform = if ($parsed.platform | is-empty) { $default_platform_lower } else { $parsed.platform }
    let entry_user = $parsed.username
    
    let check_platform = if ($input_platform | is-empty) { $default_platform_lower } else { $input_platform }
    
    let platform_matches = ($check_platform | is-empty) or ($entry_platform | is-empty) or ($entry_platform == $check_platform)
    not (($entry_user == $input_user) and $platform_matches)
  }
}

# Find the default VOUCHED file by checking common locations.
#
# Checks for VOUCHED.td in the current directory first, then .github/VOUCHED.td.
# Returns null if neither exists.
export def default-vouched-file [] {
  if ("VOUCHED.td" | path exists) {
    "VOUCHED.td"
  } else if (".github/VOUCHED.td" | path exists) {
    ".github/VOUCHED.td"
  } else {
    null
  }
}

# Open a vouched file and return all lines.
export def open-vouched-file [vouched_file?: path] {
  let file = if ($vouched_file | is-empty) {
    let default = default-vouched-file
    if ($default | is-empty) {
      error make { msg: "no VOUCHED file found" }
    }
    $default
  } else {
    $vouched_file
  }

  open $file | lines
}

# Parse a handle into platform and username components.
#
# Handles format: "platform:username" or just "username"
# Returns a record with {platform: string, username: string}
export def parse-handle [handle: string] {
  let parts = $handle | str downcase | split row ":"
  if ($parts | length) >= 2 {
    {platform: ($parts | first), username: ($parts | skip 1 | str join ":")}
  } else {
    {platform: "", username: ($parts | first)}
  }
}
