on run argv
    set appName to item 1 of argv
    if application appName is running then
        tell application appName
            set allWins to name of every window
        end tell

        -- Keep only real project windows (titled "Project — File", with an em dash),
        -- dropping Xcode auxiliary windows like "Archives", "App Shortcuts Preview"
        -- and phantom empty-named windows.
        set wns to {}
        repeat with w in allWins
            set wname to w as text
            if wname is not "" and wname contains "—" then set end of wns to wname
        end repeat
        -- Fallback for apps that don't use the "Project — File" pattern: keep all named windows.
        if (count of wns) is 0 then
            repeat with w in allWins
                set wname to w as text
                if wname is not "" then set end of wns to wname
            end repeat
        end if

        if (count of wns) is greater than 1 then
            tell application "System Events"
                activate
                set chosen to choose from list wns with prompt "Pick " & appName & " window:"
            end tell
            if chosen is not false then
                tell application appName
                    activate
                    set index of (first window whose name is item 1 of chosen) to 1
                end tell
            end if
        else if (count of wns) is 1 then
            tell application appName
                activate
                set index of (first window whose name is item 1 of wns) to 1
            end tell
        else
            tell application appName to activate
        end if
    else
        do shell script "open -a " & quoted form of (appName & ".app")
    end if
end run
