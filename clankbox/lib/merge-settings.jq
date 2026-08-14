# Merge the user's claude settings.json over the sandbox kit's, so the agent keeps
# the user's hooks + model + permissions, while the kit's bypassPermissions (YOLO)
# keys always win and host-coupled / macOS-only bits are dropped.
#
# Usage: jq -s -f merge-settings.jq KIT.json USER.json
#   KIT.json  = the settings.json the sbx claude kit wrote inside the sandbox
#   USER.json = the user's ~/.claude/settings.json on the host
.[0] as $kit
| .[1] as $user
| ( $user
    # host-path statusline, marketplace plugins — won't work in the box
    | del(.statusLine, .enabledPlugins, .extraKnownMarketplaces)
    # the Notification hook plays a macOS sound (afplay) that doesn't exist in Linux
    | if has("hooks") then .hooks |= del(.Notification) else . end
  ) as $u
# the kit's YOLO keys override whatever the user had
| $u * ( $kit
         | { defaultMode, bypassPermissionsModeAccepted, skipDangerousModePermissionPrompt,
             alwaysThinkingEnabled, themeId, apiKeyHelper }
         | with_entries(select(.value != null)) )
