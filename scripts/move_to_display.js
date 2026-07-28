#!/usr/bin/env osascript -l JavaScript

// Move the frontmost window to a display matched by name, and maximize it there.
// Usage: osascript -l JavaScript move_to_display.js 'MSI'
//
// Two ways to move a window, tried in order:
//   1. The app's own AppleScript `bounds` (Apple Events). Works for scriptable
//      apps — iTerm2, Chrome, Finder — and needs no Accessibility permission.
//   2. System Events / Accessibility. Universal, including Electron apps like
//      VS Code that aren't scriptable, but requires osascript to be granted
//      Accessibility in System Settings → Privacy & Security.
// Set MOVE_TO_DISPLAY_DEBUG=1 to trace to /tmp/move_to_display.log.

ObjC.import("AppKit");

function run(argv) {
  var pattern = String(argv[0] || "").toLowerCase();
  if (pattern === "") return;

  var target = findScreen(pattern);
  // Not connected right now: nothing to do, and not worth an error notification.
  if (target === null) {
    debug(pattern + ": not connected");
    return;
  }

  var rect = accessibilityRect(target);
  var systemEvents = Application("System Events");
  var process = systemEvents.applicationProcesses.whose({ frontmost: true })[0];

  // Reading a process's name/bundle id doesn't need Accessibility; only touching
  // its windows does.
  var bundleId;
  try {
    bundleId = process.bundleIdentifier();
  } catch (e) {
    debug("no frontmost app: " + e);
    return;
  }

  if (moveViaAppleScript(bundleId, rect)) {
    debug(pattern + ": moved " + bundleId + " via AppleScript");
    return;
  }
  if (moveViaAccessibility(process, rect)) {
    debug(pattern + ": moved " + bundleId + " via Accessibility");
    return;
  }
  debug(pattern + ": could not move " + bundleId);
}

// Case-insensitive substring match on the display name, so "MSI" finds
// "MSI MP165 E6" and survives the model string changing.
function findScreen(pattern) {
  var screens = $.NSScreen.screens;
  for (var i = 0; i < screens.count; i++) {
    var screen = screens.objectAtIndex(i);
    var name = String(ObjC.unwrap(screen.localizedName)).toLowerCase();
    if (name.indexOf(pattern) !== -1) return screen;
  }
  return null;
}

// Cocoa measures from the bottom-left of the primary screen with y going up;
// window coordinates measure from its top-left with y going down.
function accessibilityRect(screen) {
  var primaryHeight = $.NSScreen.screens.objectAtIndex(0).frame.size.height;
  var visible = screen.visibleFrame;
  return {
    x: visible.origin.x,
    y: primaryHeight - (visible.origin.y + visible.size.height),
    width: visible.size.width,
    height: visible.size.height,
  };
}

function moveViaAppleScript(bundleId, rect) {
  try {
    Application(bundleId).windows[0].bounds = rect;
    return true;
  } catch (e) {
    // Not scriptable, or no window open.
    return false;
  }
}

function moveViaAccessibility(process, rect) {
  try {
    var window = process.windows[0];
    // Position first so the window lands on the target display, then size (which
    // that display may clamp), then position again to pin the top-left corner.
    window.position = [rect.x, rect.y];
    window.size = [rect.width, rect.height];
    window.position = [rect.x, rect.y];
    return true;
  } catch (e) {
    // Fullscreen windows, apps with no accessible window, or — most likely —
    // osascript hasn't been granted Accessibility.
    debug("accessibility failed: " + e);
    return false;
  }
}

function debug(message) {
  var app = Application.currentApplication();
  app.includeStandardAdditions = true;
  try {
    if (!app.systemAttribute("MOVE_TO_DISPLAY_DEBUG")) return;
  } catch (e) {
    return;
  }
  app.doShellScript(
    "echo " +
      JSON.stringify("[" + new Date().toISOString() + "] " + message) +
      " >> /tmp/move_to_display.log"
  );
}
