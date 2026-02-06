#!/usr/bin/env nu

# Run all tests in the test suite.
#
# Discovers and runs all `test *` commands from test modules.
# Uses Nu's `std/assert` for assertions.
#
# Examples:
#
#   nu tests/run.nu
#   nu tests/run.nu --filter "from-td"

def main [
  --filter: string = "",  # Only run tests matching this substring
] {
  # Discover test modules: every .nu file in this directory except run.nu.
  const dir = path self | path dirname
  let modules = (
    glob ($dir | path join "*.nu")
    | where { |f| ($f | path basename) != "run.nu" }
    | sort
    | each { |f|
      { name: ($f | path basename | str replace ".nu" ""), path: $f }
    }
  )

  mut total = 0
  mut passed = 0
  mut failed = 0
  mut failures = []

  for mod in $modules {
    # Import the module in a subprocess and list all exported commands
    # whose name starts with "test ".
    let commands = (
      nu -c $'use ($mod.path) *; scope commands | where name =~ "^test " | get name | to json'
      | from json
    )

    for test_name in $commands {
      # Skip tests that don't match the filter, if one was provided.
      if (not ($filter | is-empty)) and (not ($test_name | str contains $filter)) {
        continue
      }

      $total += 1

      # Run each test in its own subprocess so failures are isolated.
      let result = do {
        nu -c $'use ($mod.path) *; ($test_name)'
      } | complete

      if $result.exit_code == 0 {
        $passed += 1
        print $"  (ansi green)✓(ansi reset) ($mod.name): ($test_name)"
      } else {
        $failed += 1
        $failures = ($failures | append { module: $mod.name, test: $test_name, stderr: $result.stderr })
        print $"  (ansi red)✗(ansi reset) ($mod.name): ($test_name)"
      }
    }
  }

  # Print summary.
  print ""
  print $"(ansi white_bold)Results: ($passed)/($total) passed(ansi reset)"

  # If any tests failed, print details and exit with a non-zero code.
  if $failed > 0 {
    print ""
    print $"(ansi red_bold)Failures:(ansi reset)"
    for f in $failures {
      print $"  (ansi red)✗(ansi reset) ($f.module): ($f.test)"
      print $"    ($f.stderr | str trim)"
    }
    exit 1
  }
}
