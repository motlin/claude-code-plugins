#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPTS="$PROJECT_ROOT/plugins/demo/scripts"
    SOURCE="$BATS_TEST_TMPDIR/demo-source"
    PUBLISH="$BATS_TEST_TMPDIR/publish-root"
    mkdir -p "$SOURCE"
}

seed_demo() {
    printf '# One POST, end to end\n' >"$SOURCE/demo.md"
    printf '<!doctype html><title>One POST</title>\n' >"$SOURCE/demo.html"
}

render_or_skip() {
    if ! "$SCRIPTS/demo-render.py" "$1" >/dev/null 2>"$BATS_TEST_TMPDIR/render-err"; then
        skip "markdown renderer unavailable: $(cat "$BATS_TEST_TMPDIR/render-err")"
    fi
}

# demo-presence

@test "demo-presence reports away when idle beyond the threshold" {
    DEMO_IDLE_SECONDS=999 DEMO_SCREEN_LOCKED=false DEMO_IDLE_THRESHOLD=300 \
        run "$SCRIPTS/demo-presence"

    [ "$status" -eq 1 ]
    [[ "$output" == *"verdict=away"* ]]
    [[ "$output" == *"idle_seconds=999"* ]]
}

@test "demo-presence reports present when recently active and unlocked" {
    DEMO_IDLE_SECONDS=5 DEMO_SCREEN_LOCKED=false DEMO_IDLE_THRESHOLD=300 \
        run "$SCRIPTS/demo-presence"

    [ "$status" -eq 0 ]
    [[ "$output" == *"verdict=present"* ]]
}

@test "demo-presence treats a locked screen as away however recent the activity" {
    DEMO_IDLE_SECONDS=0 DEMO_SCREEN_LOCKED=true DEMO_IDLE_THRESHOLD=300 \
        run "$SCRIPTS/demo-presence"

    [ "$status" -eq 1 ]
    [[ "$output" == *"verdict=away"* ]]
}

@test "demo-presence reports unknown when no reading is available" {
    DEMO_IDLE_SECONDS=unknown DEMO_SCREEN_LOCKED=unknown \
        run "$SCRIPTS/demo-presence"

    [ "$status" -eq 2 ]
    [[ "$output" == *"verdict=unknown"* ]]
}

stub_macos() {
    local lock_entry="$1" idle_nanoseconds="${2:-1000000000}"
    STUBS="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STUBS"

    printf '#!/bin/sh\necho Darwin\n' >"$STUBS/uname"

    {
        printf '#!/bin/sh\n'
        printf 'case "$*" in\n'
        printf '  *IOHIDSystem*) echo "    \\"HIDIdleTime\\" = %s" ;;\n' "$idle_nanoseconds"
        printf '  *) cat <<XML\n%s\nXML\n  ;;\n' "$lock_entry"
        printf 'esac\n'
    } >"$STUBS/ioreg"

    chmod +x "$STUBS/uname" "$STUBS/ioreg"
    PATH="$STUBS:$PATH"
}

@test "demo-presence reads a locked screen from the macOS session dictionary" {
    stub_macos '<key>CGSSessionScreenIsLocked</key>
<true/>
<key>CGSSessionIDKey</key>'

    PATH="$PATH" run "$SCRIPTS/demo-presence"

    [ "$status" -eq 1 ]
    [[ "$output" == *"screen_locked=true"* ]]
}

@test "demo-presence treats an absent lock key as unlocked when a GUI session exists" {
    stub_macos '<key>CGSSessionIDKey</key>
<integer>257</integer>
<key>CGSSessionOnConsoleKey</key>'

    PATH="$PATH" run "$SCRIPTS/demo-presence"

    [ "$status" -eq 0 ]
    [[ "$output" == *"screen_locked=false"* ]]
    [[ "$output" == *"verdict=present"* ]]
}

@test "demo-presence reports an unknown lock state when there is no GUI session" {
    stub_macos '<key>IOPlatformUUID</key>'

    PATH="$PATH" run "$SCRIPTS/demo-presence"

    [[ "$output" == *"screen_locked=unknown"* ]]
}

# demo-publish

@test "demo-publish prints the URL for the published demo" {
    seed_demo

    DEMO_PUBLISH_DIR="$PUBLISH" DEMO_PUBLISH_URL="https://demo.example/" \
        run --separate-stderr "$SCRIPTS/demo-publish" "$SOURCE"

    [ "$status" -eq 0 ]
    [ "$output" = "https://demo.example/demo-source/" ]
    [ -f "$PUBLISH/demo-source/demo.md" ]
}

@test "demo-publish serves the rendered page at the bare directory URL" {
    seed_demo

    DEMO_PUBLISH_DIR="$PUBLISH" DEMO_PUBLISH_URL="https://demo.example" \
        run --separate-stderr "$SCRIPTS/demo-publish" "$SOURCE"

    [ "$status" -eq 0 ]
    [ -f "$PUBLISH/demo-source/index.html" ]
    [ "$(cat "$PUBLISH/demo-source/index.html")" = "$(cat "$SOURCE/demo.html")" ]
}

@test "demo-publish reports the path instead of inventing a URL when none is configured" {
    seed_demo

    DEMO_PUBLISH_DIR="$PUBLISH" DEMO_PUBLISH_URL='' \
        run --separate-stderr "$SCRIPTS/demo-publish" "$SOURCE"

    [ "$status" -eq 0 ]
    [ "$output" = "$PUBLISH/demo-source" ]
}

@test "demo-publish drops files that no longer exist in the demo" {
    seed_demo
    printf 'stale\n' >"$SOURCE/stale.txt"
    DEMO_PUBLISH_DIR="$PUBLISH" run --separate-stderr "$SCRIPTS/demo-publish" "$SOURCE"
    [ -f "$PUBLISH/demo-source/stale.txt" ]

    rm "$SOURCE/stale.txt"
    DEMO_PUBLISH_DIR="$PUBLISH" run --separate-stderr "$SCRIPTS/demo-publish" "$SOURCE"

    [ "$status" -eq 0 ]
    [ ! -f "$PUBLISH/demo-source/stale.txt" ]
    [ -f "$PUBLISH/demo-source/demo.md" ]
}

@test "demo-publish warns when the demo has no rendered page" {
    printf '# Unrendered\n' >"$SOURCE/demo.md"

    DEMO_PUBLISH_DIR="$PUBLISH" run --separate-stderr "$SCRIPTS/demo-publish" "$SOURCE"

    [ "$status" -eq 0 ]
    [[ "$stderr" == *"no rendered page"* ]]
}

@test "demo-publish fails on a demo directory that does not exist" {
    DEMO_PUBLISH_DIR="$PUBLISH" run --separate-stderr "$SCRIPTS/demo-publish" "$BATS_TEST_TMPDIR/absent"

    [ "$status" -eq 1 ]
    [ ! -d "$PUBLISH/absent" ]
}

@test "demo-publish publishes under the name it is given" {
    seed_demo

    DEMO_PUBLISH_DIR="$PUBLISH" DEMO_PUBLISH_URL="https://demo.example" \
        run --separate-stderr "$SCRIPTS/demo-publish" --name import-pipeline "$SOURCE"

    [ "$status" -eq 0 ]
    [ "$output" = "https://demo.example/import-pipeline/" ]
    [ -f "$PUBLISH/import-pipeline/demo.md" ]
}

# demo-render

@test "demo-render titles the page from the document's first heading" {
    printf '# Notes service\n\nBody text.\n' >"$SOURCE/demo.md"
    render_or_skip "$SOURCE/demo.md"

    run "$SCRIPTS/demo-render.py" "$SOURCE/demo.md"

    [ "$status" -eq 0 ]
    [[ "$output" == *"<title>Notes service</title>"* ]]
    [[ "$output" == *"<!doctype html>"* ]]
}

@test "demo-render omits the document skeleton in fragment mode" {
    printf '# Notes service\n\nBody text.\n' >"$SOURCE/demo.md"
    render_or_skip "$SOURCE/demo.md"

    run "$SCRIPTS/demo-render.py" "$SOURCE/demo.md" --fragment

    [ "$status" -eq 0 ]
    [[ "$output" == *"<title>Notes service</title>"* ]]
    [[ "$output" != *"<!doctype"* ]]
    [[ "$output" != *"<body"* ]]
}

@test "demo-render inlines a relative image so the page stands alone" {
    printf '# With image\n\n![shot](shot.png)\n' >"$SOURCE/demo.md"
    printf 'PNGDATA' >"$SOURCE/shot.png"
    render_or_skip "$SOURCE/demo.md"

    run "$SCRIPTS/demo-render.py" "$SOURCE/demo.md"

    [ "$status" -eq 0 ]
    [[ "$output" == *"data:image/png;base64,"* ]]
    [[ "$output" != *'src="shot.png"'* ]]
}

@test "demo-render leaves an absolute image URL alone" {
    printf '# Remote\n\n![remote](https://example.com/a.png)\n' >"$SOURCE/demo.md"
    render_or_skip "$SOURCE/demo.md"

    run "$SCRIPTS/demo-render.py" "$SOURCE/demo.md"

    [ "$status" -eq 0 ]
    [[ "$output" == *'src="https://example.com/a.png"'* ]]
}
