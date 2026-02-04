#!/usr/bin/env nu

# Vouch - contributor trust management.
export def main [] {
  print "Usage: vouch <command>"
  print ""
  print "Local Commands:"
  print "  add               Add a user to the vouched contributors list"
  print "  check             Check a user's vouch status"
  print "  denounce          Denounce a user by adding them to the vouched file"
  print ""
  print "GitHub integration:"
  print "  gh-check-pr         Check if a PR author is a vouched contributor"
  print "  gh-manage-by-issue  Manage contributor status via issue comment"
}

# The main CLI commands, this lets the user do `use vouch; vouch add` etc.
export use cli.nu [
  add
  check
  denounce
  gh-check-pr
  gh-manage-by-issue
]

# Library
export module lib.nu
