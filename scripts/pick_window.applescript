on run argv
    set appName to item 1 of argv
    if application appName is not running then
        do shell script "open -a " & quoted form of (appName & ".app")
        return
    end if

    set winInfo to my collectWindows(appName)
    set winNames to item 1 of winInfo
    set winIDs to item 2 of winInfo
    set winPaths to item 3 of winInfo

    set labels to {}
    set hints to {}
    set ids to {}
    set names to {}

    -- Preferred labelling: use each window's document path so entries read like
    -- Xcode's "Open Recent" menu, i.e. "E-Sim.xcworkspace — esim-b2c-ios".
    -- That keeps several checkouts of the same project distinguishable.
    repeat with i from 1 to (count of winPaths)
        set p to item i of winPaths
        if p is not "" then
            set end of labels to my projectLabel(p)
            set end of hints to my fileFromTitle(item i of winNames)
            set end of ids to item i of winIDs
            set end of names to item i of winNames
        end if
    end repeat

    -- Fallback for apps that don't expose document paths: show window titles, dropping
    -- auxiliary windows (Xcode's "Archives", "Organizer") and phantom empty-named ones.
    if (count of labels) is 0 then
        repeat with i from 1 to (count of winNames)
            set n to item i of winNames
            if n is not "" and n contains "—" then
                set end of labels to n
                set end of hints to ""
                set end of ids to item i of winIDs
                set end of names to n
            end if
        end repeat
    end if
    if (count of labels) is 0 then
        repeat with i from 1 to (count of winNames)
            set n to item i of winNames
            if n is not "" then
                set end of labels to n
                set end of hints to ""
                set end of ids to item i of winIDs
                set end of names to n
            end if
        end repeat
    end if

    set labels to my disambiguate(labels, hints)

    if (count of labels) is greater than 1 then
        tell application "System Events"
            activate
            set chosen to choose from list labels with prompt "Pick " & appName & " window:"
        end tell
        if chosen is not false then
            set pos to my indexOf(labels, item 1 of chosen)
            if pos is greater than 0 then my raiseWindow(appName, item pos of ids, item pos of names)
        end if
    else if (count of labels) is 1 then
        my raiseWindow(appName, item 1 of ids, item 1 of names)
    else
        tell application appName to activate
    end if
end run

-- The app name only arrives at runtime, so app-specific terminology (document, path)
-- can't be compiled into this script; `run script` compiles it against the real app.
on collectWindows(appName)
    set src to my joinLines({¬
        "tell application \"" & my escapeText(appName) & "\"", ¬
        "set nms to {}", ¬
        "set wids to {}", ¬
        "set pths to {}", ¬
        "repeat with i from 1 to (count of windows)", ¬
        "set n to \"\"", ¬
        "try", ¬
        "set n to (name of window i) as text", ¬
        "end try", ¬
        "set theID to -1", ¬
        "try", ¬
        "set theID to id of window i", ¬
        "end try", ¬
        "set p to \"\"", ¬
        "try", ¬
        "set p to (path of document of window i) as text", ¬
        "end try", ¬
        "set end of nms to n", ¬
        "set end of wids to theID", ¬
        "set end of pths to p", ¬
        "end repeat", ¬
        "return {nms, wids, pths}", ¬
        "end tell"})
    try
        return run script src
    on error
        return {{}, {}, {}}
    end try
end collectWindows

on raiseWindow(appName, wid, wname)
    set prefix to "tell application \"" & my escapeText(appName) & "\"" & linefeed & "activate" & linefeed
    if wid is not -1 then
        try
            run script (prefix & "set index of (first window whose id is " & wid & ") to 1" & linefeed & "end tell")
            return
        end try
    end if
    try
        run script (prefix & "set index of (first window whose name is \"" & my escapeText(wname) & "\") to 1" & linefeed & "end tell")
    on error
        tell application appName to activate
    end try
end raiseWindow

-- "/…/esim-b2c-ios/E-Sim.xcworkspace" -> "E-Sim.xcworkspace — esim-b2c-ios"
on projectLabel(pth)
    set base to my lastComponent(pth)
    set parentDir to my lastComponent(my parentPath(pth))
    if parentDir is "" then return base
    return base & " — " & parentDir
end projectLabel

on lastComponent(pth)
    set pth to my trimTrailingSlash(pth)
    if pth is "" then return ""
    set savedDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "/"
    set comps to text items of pth
    set AppleScript's text item delimiters to savedDelims
    return item -1 of comps
end lastComponent

on parentPath(pth)
    set pth to my trimTrailingSlash(pth)
    set savedDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "/"
    set comps to text items of pth
    if (count of comps) is less than 2 then
        set AppleScript's text item delimiters to savedDelims
        return ""
    end if
    set res to (items 1 thru -2 of comps) as text
    set AppleScript's text item delimiters to savedDelims
    return res
end parentPath

on trimTrailingSlash(pth)
    repeat while pth ends with "/" and (length of pth) is greater than 1
        set pth to text 1 thru -2 of pth
    end repeat
    return pth
end trimTrailingSlash

-- "E-Sim — Shared.swift" -> "Shared.swift"
on fileFromTitle(title)
    if title does not contain "—" then return ""
    set savedDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "—"
    set comps to text items of title
    set AppleScript's text item delimiters to savedDelims
    set tailPart to item -1 of comps
    repeat while tailPart starts with " "
        set tailPart to text 2 thru -1 of tailPart
    end repeat
    return tailPart
end fileFromTitle

-- Several windows can share one project; tag those with the file they're showing.
on disambiguate(labels, hints)
    set original to labels
    repeat with i from 1 to (count of labels)
        if my countOf(original, item i of original) is greater than 1 then
            set hint to item i of hints
            if hint is not "" then set item i of labels to (item i of labels) & " (" & hint & ")"
        end if
    end repeat
    repeat with i from 1 to (count of labels)
        if my countOf(labels, item i of labels) is greater than 1 then
            set item i of labels to (item i of labels) & " [" & i & "]"
        end if
    end repeat
    return labels
end disambiguate

on countOf(lst, value)
    set n to 0
    repeat with x in lst
        if (x as text) is value then set n to n + 1
    end repeat
    return n
end countOf

on indexOf(lst, value)
    repeat with i from 1 to (count of lst)
        if (item i of lst as text) is value then return i
    end repeat
    return 0
end indexOf

on joinLines(lst)
    set savedDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to linefeed
    set res to lst as text
    set AppleScript's text item delimiters to savedDelims
    return res
end joinLines

on escapeText(t)
    set t to my replaceText(t, "\\", "\\\\")
    return my replaceText(t, "\"", "\\\"")
end escapeText

on replaceText(t, findText, replaceWith)
    set savedDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to findText
    set comps to text items of t
    set AppleScript's text item delimiters to replaceWith
    set res to comps as text
    set AppleScript's text item delimiters to savedDelims
    return res
end replaceText
