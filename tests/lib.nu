use std/assert

use ../vouch/file.nu ["from td", "to td"]
use ../vouch/lib.nu [add-user, check-user, denounce-user, remove-user]

def sample-records [] {
  "# Comment
mitchellh
github:alice
-github:badguy
-github:spammer Reason here" | from td
}

# --- check-user ---

export def "test check-user finds vouched user" [] {
  let result = sample-records | check-user "mitchellh"
  assert equal $result "vouched"
}

export def "test check-user finds vouched user with platform" [] {
  let result = sample-records | check-user "github:alice"
  assert equal $result "vouched"
}

export def "test check-user finds denounced user" [] {
  let result = sample-records | check-user "github:badguy"
  assert equal $result "denounced"
}

export def "test check-user returns unknown for missing user" [] {
  let result = sample-records | check-user "nobody"
  assert equal $result "unknown"
}

export def "test check-user is case insensitive" [] {
  let result = sample-records | check-user "MitchellH"
  assert equal $result "vouched"
}

export def "test check-user matches with default platform" [] {
  let result = sample-records | check-user "alice" --default-platform github
  assert equal $result "vouched"
}

export def "test check-user denounced with default platform" [] {
  let result = sample-records | check-user "badguy" --default-platform github
  assert equal $result "denounced"
}

# --- add-user ---

export def "test add-user adds new user" [] {
  let result = sample-records | add-user "newuser"
  let status = $result | check-user "newuser"
  assert equal $status "vouched"
}

export def "test add-user adds user with platform" [] {
  let result = sample-records | add-user "github:newuser"
  let status = $result | check-user "github:newuser"
  assert equal $status "vouched"
}

export def "test add-user replaces denounced user" [] {
  let result = sample-records | add-user "github:badguy"
  let status = $result | check-user "github:badguy"
  assert equal $status "vouched"
}

export def "test add-user preserves comments" [] {
  let result = sample-records | add-user "newuser"
  let comments = $result | where type == "comment"
  assert equal ($comments | length) 1
}

export def "test add-user result is sorted" [] {
  let result = sample-records | add-user "zzz"
  let entries = $result | where { |r| $r.type == "vouch" or $r.type == "denounce" }
  let usernames = $entries | get username
  let sorted = $usernames | sort -i
  assert equal $usernames $sorted
}

# --- denounce-user ---

export def "test denounce-user denounces a user" [] {
  let result = sample-records | denounce-user "newbad"
  let status = $result | check-user "newbad"
  assert equal $status "denounced"
}

export def "test denounce-user with reason" [] {
  let result = sample-records | denounce-user "newbad" "spam"
  let entry = $result | where username == "newbad" | first
  assert equal $entry.details "spam"
}

export def "test denounce-user replaces vouched user" [] {
  let result = sample-records | denounce-user "mitchellh"
  let status = $result | check-user "mitchellh"
  assert equal $status "denounced"
}

export def "test denounce-user preserves comments" [] {
  let result = sample-records | denounce-user "newbad"
  let comments = $result | where type == "comment"
  assert equal ($comments | length) 1
}

# --- remove-user ---

export def "test remove-user removes vouched user" [] {
  let result = sample-records | remove-user "mitchellh"
  let status = $result | check-user "mitchellh"
  assert equal $status "unknown"
}

export def "test remove-user removes denounced user" [] {
  let result = sample-records | remove-user "github:badguy"
  let status = $result | check-user "github:badguy"
  assert equal $status "unknown"
}

export def "test remove-user preserves other entries" [] {
  let result = sample-records | remove-user "mitchellh"
  let status = $result | check-user "github:alice"
  assert equal $status "vouched"
}

export def "test remove-user preserves comments" [] {
  let result = sample-records | remove-user "mitchellh"
  let comments = $result | where type == "comment"
  assert equal ($comments | length) 1
}

export def "test remove-user noop for missing user" [] {
  let before = sample-records
  let after = $before | remove-user "nobody"
  assert equal ($after | length) ($before | length)
}

# --- roundtrip ---

export def "test add-user roundtrips through td format" [] {
  let result = sample-records | add-user "newuser" | to td | from td | check-user "newuser"
  assert equal $result "vouched"
}

export def "test denounce-user roundtrips through td format" [] {
  let result = sample-records | denounce-user "newbad" "reason" | to td | from td | check-user "newbad"
  assert equal $result "denounced"
}
