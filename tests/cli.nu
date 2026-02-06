use std/assert

use ../vouch/file.nu ["from td"]

def with-temp-vouched [block: closure] {
  let dir = mktemp -d
  let file = $dir | path join "VOUCHED.td"
  "# Comment
mitchellh
github:alice
-github:badguy" | save $file
  try {
    do $block $file
  } catch { |e|
    rm -rf $dir
    error make { msg: $e.msg }
  }
  rm -rf $dir
}

# --- add ---

export def "test cli add previews by default" [] {
  with-temp-vouched { |file|
    let output = nu -c $'use vouch *; add newuser --vouched-file ($file)'
    assert ($output | str contains "newuser")
    let contents = open --raw $file | from td
    let status_after = $contents | where username == "newuser"
    assert equal ($status_after | length) 0 "file should not be modified"
  }
}

export def "test cli add writes with --write" [] {
  with-temp-vouched { |file|
    nu -c $'use vouch *; add newuser --vouched-file ($file) --write'
    let contents = open --raw $file | from td
    let entry = $contents | where username == "newuser" | first
    assert equal $entry.type "vouch"
  }
}

export def "test cli add replaces denounced with --write" [] {
  with-temp-vouched { |file|
    nu -c $'use vouch *; add github:badguy --vouched-file ($file) --write'
    let contents = open --raw $file | from td
    let entry = $contents | where username == "badguy" | first
    assert equal $entry.type "vouch"
  }
}

# --- check ---

export def "test cli check vouched exits 0" [] {
  with-temp-vouched { |file|
    let result = do { nu -c $'use vouch *; check mitchellh --vouched-file ($file)' } | complete
    assert equal $result.exit_code 0
    assert ($result.stdout | str contains "vouched")
  }
}

export def "test cli check denounced exits 1" [] {
  with-temp-vouched { |file|
    let result = do { nu -c $'use vouch *; check github:badguy --vouched-file ($file)' } | complete
    assert equal $result.exit_code 1
    assert ($result.stdout | str contains "denounced")
  }
}

export def "test cli check unknown exits 2" [] {
  with-temp-vouched { |file|
    let result = do { nu -c $'use vouch *; check nobody --vouched-file ($file)' } | complete
    assert equal $result.exit_code 2
    assert ($result.stdout | str contains "unknown")
  }
}

# --- denounce ---

export def "test cli denounce previews by default" [] {
  with-temp-vouched { |file|
    let output = nu -c $'use vouch *; denounce eviluser --vouched-file ($file)'
    assert ($output | str contains "eviluser")
    let contents = open --raw $file | from td
    let entry = $contents | where username == "eviluser"
    assert equal ($entry | length) 0 "file should not be modified"
  }
}

export def "test cli denounce writes with --write" [] {
  with-temp-vouched { |file|
    nu -c $'use vouch *; denounce eviluser --vouched-file ($file) --write'
    let contents = open --raw $file | from td
    let entry = $contents | where username == "eviluser" | first
    assert equal $entry.type "denounce"
  }
}

export def "test cli denounce with reason" [] {
  with-temp-vouched { |file|
    nu -c $'use vouch *; denounce eviluser --vouched-file ($file) --write --reason "AI slop"'
    let contents = open --raw $file | from td
    let entry = $contents | where username == "eviluser" | first
    assert equal $entry.type "denounce"
    assert equal $entry.details "AI slop"
  }
}
