-- mainly stolen from https://gitlab.com/dwt1/dotfiles/-/blob/master/.xmonad/xmonad.hs
  -- Base
import GHC.IO.Handle.Types (Handle)
import System.Directory
import System.Exit (exitSuccess)
import System.IO (hPutStrLn)
import XMonad
import qualified Debug.Trace as T
import qualified XMonad.StackSet as W

    -- Actions
import XMonad.Actions.CopyWindow (kill1)
import XMonad.Actions.CycleWS (Direction1D(..), moveTo, shiftTo, WSType(..), nextScreen, prevScreen)
import XMonad.Actions.GridSelect
import XMonad.Actions.MouseResize
import XMonad.Actions.Promote
import XMonad.Actions.RotSlaves (rotSlavesDown, rotAllDown)
import XMonad.Actions.UpdatePointer (updatePointer)
import XMonad.Actions.WindowGo (runOrRaise)
import XMonad.Actions.WithAll (sinkAll, killAll)
import qualified XMonad.Actions.Search as S

    -- Data
import Data.Char (isSpace, toUpper)
import Data.List (zipWith)
import Data.Maybe (fromJust, isJust)
import Data.Maybe (isJust)
import Data.Monoid
import Data.Ratio -- this makes the '%' operator available (optional)
import Data.Tree
import qualified Data.Map as M

    -- Hooks
import XMonad.Hooks.DynamicLog (dynamicLogWithPP, wrap, xmobarPP, xmobarColor, shorten, PP(..))
import XMonad.Hooks.EwmhDesktops  -- for some fullscreen events, also for xcomposite in obs.
import XMonad.Hooks.ManageDocks (avoidStruts, docksEventHook, manageDocks, ToggleStruts(..))
import XMonad.Hooks.ManageHelpers (isFullscreen, doFullFloat, doCenterFloat)
import XMonad.Hooks.ServerMode
import XMonad.Hooks.SetWMName
import XMonad.Hooks.WorkspaceHistory

    -- Layouts
import XMonad.Layout.Accordion
import XMonad.Layout.GridVariants (Grid(Grid))
import XMonad.Layout.ResizableTile
import XMonad.Layout.SimplestFloat
import XMonad.Layout.Spiral
import XMonad.Layout.Tabbed
import XMonad.Layout.ThreeColumns

    -- Layouts modifiers
import XMonad.Layout.LayoutModifier
import XMonad.Layout.LimitWindows (limitWindows, increaseLimit, decreaseLimit)
import XMonad.Layout.Magnifier
import XMonad.Layout.MultiToggle (mkToggle, single, EOT(EOT), (??))
import XMonad.Layout.MultiToggle.Instances (StdTransformers(NBFULL, MIRROR, NOBORDERS))
import XMonad.Layout.NoBorders
import XMonad.Layout.Renamed
import XMonad.Layout.ShowWName
import XMonad.Layout.Simplest
import XMonad.Layout.Spacing
import XMonad.Layout.SubLayouts
import XMonad.Layout.WindowArranger (windowArrange, WindowArrangerMsg(..))
import XMonad.Layout.WindowNavigation
import qualified XMonad.Layout.MultiToggle as MT (Toggle(..))
import qualified XMonad.Layout.ToggleLayouts as T (toggleLayouts, ToggleLayout(Toggle))

   -- Utilities
import XMonad.Util.Dmenu
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Util.NamedScratchpad
import XMonad.Util.Run (runProcessWithInput, safeSpawn, spawnPipe)
import XMonad.Util.SpawnOnce

-- SETTINGS

myFont :: String
myFont = "xft:SauceCodePro Nerd Font Mono:regular:size=9:antialias=true:hinting=true"

myModMask :: KeyMask
myModMask = mod4Mask        -- Sets modkey to super/windows key

myTerminal :: String
myTerminal = "wezterm"    -- Sets default terminal

myFileExplorer :: String
myFileExplorer = "nautilus"    -- Sets default file explorer

myBrowser :: String
myBrowser = "firefox "  -- Sets qutebrowser as browser

myBorderWidth :: Dimension
myBorderWidth = 1           -- Sets border width for windows

myNormColor :: String
myNormColor   = "#282c34"   -- Border color of normal windows

myFocusColor :: String
myFocusColor  = "#46d9ff"   -- Border color of focused windows

windowCount :: X (Maybe String)
windowCount = gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset

--Makes setting the spacingRaw simpler to write. The spacingRaw module adds a configurable amount of space around windows.
mySpacing :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True

-- Below is a variation of the above except no borders are applied
-- if fewer than two windows. So a single window has no gaps.
mySpacing' :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing' i = spacingRaw True (Border i i i i) True (Border i i i i) True

-- Startup

myStartupHook :: X ()
myStartupHook = do
    spawnOnce "nm-applet &"
    spawnOnce "nitrogen --restore"
    spawnOnce "compton"
    spawnOnce "launch-redshift --auto 6500:2500"
    spawnOnce "launch-volume-control"
    spawnOnce "albert"
    spawnOnce "trayer --edge top --align right --widthtype request --padding 6 --SetDockType true --SetPartialStrut true --expand true --monitor 1 --transparent true --alpha 0 --tint 0x000000  --height 22 &"
    spawnOnce "setxkbmap lv -variant apostrophe"
    spawnOnce "enable-numlock-if-var"
    -- spawnOnce "launch-xob"
    setWMName "LG3D"

-- Colors

myColorizer :: Window -> Bool -> X (String, String)
myColorizer = colorRangeFromClassName
                  (0x28,0x2c,0x34) -- lowest inactive bg
                  (0x28,0x2c,0x34) -- highest inactive bg
                  (0xc7,0x92,0xea) -- active bg
                  (0xc0,0xa7,0x9a) -- inactive fg
                  (0x28,0x2c,0x34) -- active fg

myTabTheme = def { fontName            = myFont
                 , activeColor         = "#46d9ff"
                 , inactiveColor       = "#313846"
                 , activeBorderColor   = "#46d9ff"
                 , inactiveBorderColor = "#282c34"
                 , activeTextColor     = "#282c34"
                 , inactiveTextColor   = "#d0d0d0"
                 }

myShowWNameTheme :: SWNConfig
myShowWNameTheme = def
    { swn_font              = "xft:Ubuntu:bold:size=60"
    , swn_fade              = 1.0
    , swn_bgcolor           = "#1c1f24"
    , swn_color             = "#ffffff"
    }

-- ScratchPads

scratchpads :: [NamedScratchpad]
scratchpads = [
                    NS "authy" "authy" (className =? "Authy Desktop") (customFloating $ center 0.3 0.3),
                    NS "blueberry" "blueberry" (className =? "Blueberry.py") (customFloating $ center 0.6 0.6),
                    NS "btop" "wezterm start --class btop -- btop" (className =? "btop") (customFloating $ center 0.6 0.6),
                    NS "ctop" "wezterm start --class ctop -- ctop" (className =? "ctop") (customFloating $ center 0.6 0.6),
                    NS "mailspring" "mailspring" (className =? "Mailspring") (customFloating $ center 0.9 0.9),
                    NS "notion" "notion-app" (className =? "notion-app") (customFloating $ center 0.9 0.9),
                    NS "slack" "slack" (className =? "Slack") (customFloating $ center 0.9 0.9),
                    NS "spotify" "spotify" (className =? "Spotify") (customFloating $ center 0.6 0.6),
                    NS "terminal" "wezterm start --class terminal" (className =? "terminal") (customFloating $ center 0.6 0.6),
                    NS "todo" "todoist" (className =? "Todoist") (customFloating $ center 0.6 0.9),
                    NS "1password" "1password" (className =? "1Password") (customFloating $ center 0.6 0.9)
                ]
                where center w h = W.RationalRect ((1 - w) / 2) ((1 - h) / 2) w h

-- Layouts
-- Defining a bunch of layouts, many that I don't use.
-- limitWindows n sets maximum number of windows displayed for layout.
-- mySpacing n sets the gap size around the windows.
tall     = renamed [Replace "tall"]
           $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (smartBorders Simplest)
           $ limitWindows 12
           $ mySpacing 0
           $ ResizableTall 1 (3/100) (1/2) []
-- magnify  = renamed [Replace "magnify"]
--            $ smartBorders
--            $ windowNavigation
--            $ addTabs shrinkText myTabTheme
--            $ subLayout [] (smartBorders Simplest)
--            $ magnifier
--            $ limitWindows 12
--            $ mySpacing 0
--            $ ResizableTall 1 (3/100) (1/2) []
-- monocle  = renamed [Replace "monocle"]
--            $ smartBorders
--            $ windowNavigation
--            $ addTabs shrinkText myTabTheme
--            $ subLayout [] (smartBorders Simplest)
--            $ limitWindows 20 Full
floats   = renamed [Replace "floats"]
           $ smartBorders
           $ limitWindows 20 simplestFloat
grid     = renamed [Replace "grid"]
           $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (smartBorders Simplest)
           $ limitWindows 12
           $ mySpacing 0
           $ mkToggle (single MIRROR)
           $ Grid (16/10)
spirals  = renamed [Replace "spirals"]
           $ smartBorders
           $ windowNavigation
           $ addTabs shrinkText myTabTheme
           $ subLayout [] (smartBorders Simplest)
           $ mySpacing' 0
           $ spiral (6/7)
-- threeCol = renamed [Replace "threeCol"]
--            $ smartBorders
--            $ windowNavigation
--            $ addTabs shrinkText myTabTheme
--            $ subLayout [] (smartBorders Simplest)
--            $ limitWindows 7
--            $ ThreeCol 1 (3/100) (1/2)
-- threeRow = renamed [Replace "threeRow"]
--            $ smartBorders
--            $ windowNavigation
--            $ addTabs shrinkText myTabTheme
--            $ subLayout [] (smartBorders Simplest)
--            $ limitWindows 7
           -- -- Mirror takes a layout and rotates it by 90 degrees.
           -- -- So we are applying Mirror to the ThreeCol layout.
           -- $ Mirror
           -- $ ThreeCol 1 (3/100) (1/2)
-- tabs     = renamed [Replace "tabs"]
--            -- I cannot add spacing to this layout because it will
--            -- add spacing between window and tabs which looks bad.
--            $ tabbed shrinkText myTabTheme
-- tallAccordion  = renamed [Replace "tallAccordion"]
--            $ Accordion
-- wideAccordion  = renamed [Replace "wideAccordion"]
--            $ Mirror Accordion

-- Layout Hook

myLayoutHook = avoidStruts $ mouseResize $ windowArrange $ T.toggleLayouts floats
               $ mkToggle (NBFULL ?? NOBORDERS ?? EOT) myDefaultLayout
             where
               myDefaultLayout =     withBorder myBorderWidth tall
                                 -- ||| magnify
                                 -- ||| noBorders monocle
                                 ||| floats
                                 -- ||| noBorders tabs
                                 ||| grid
                                 ||| spirals
                                 -- ||| threeCol
                                 -- ||| threeRow
                                 -- ||| tallAccordion
                                 -- ||| wideAccordion

-- Workspaces

myWorkspaces = [" www ", " dev ", " 3 ", " 4 ", " 5 ", " 6 ", " 7 ", " 8 ", " 9 "]
myWorkspaceIndices = M.fromList $ zipWith (,) myWorkspaces [1..] -- (,) == \x y -> (x,y)

clickable ws = "<action=xdotool key super+"++show i++"> "++ws++" </action>"
    where i = fromJust $ M.lookup ws myWorkspaceIndices

-- ManageHook

myManageHook :: XMonad.Query (Data.Monoid.Endo WindowSet)
myManageHook = composeAll
     -- 'doFloat' forces a window to float.  Useful for dialog boxes and such.
     -- using 'doShift ( myWorkspaces !! 7)' sends program to workspace 8!
     -- I'm doing it this way because otherwise I would have to write out the full
     -- name of my workspaces and the names would be very long if using clickable workspaces.
     [ className =? "confirm"         --> doFloat
     , className =? "file_progress"   --> doFloat
     , className =? "dialog"          --> doFloat
     , className =? "download"        --> doFloat
     , className =? "error"           --> doFloat
     , className =? "notification"    --> doFloat
     , className =? "splash"          --> doFloat
     , className =? "toolbar"         --> doFloat
     , className =? "Peek"            --> doFloat
     , title =? "Mozilla Firefox"     --> doShift ( myWorkspaces !! 0 )
     , className =? "VirtualBox Manager" --> doShift  ( myWorkspaces !! 4 )
     , (className =? "firefox" <&&> resource =? "Dialog") --> doFloat  -- Float Firefox Dialog
     , (title     =? "Picture-in-Picture") --> doFloat
     , isFullscreen -->  doFullFloat
     , manageHook defaultConfig
     ] <+> namedScratchpadManageHook scratchpads

-- Binds

-- START_KEYS
myKeys :: [(String, X ())]
myKeys = [
    -- KB_GROUP Xmonad
        ("M-S-M1-q",                io exitSuccess), -- quit xmonad
        ("M-q",                    spawn "pkill xmobar; xmonad --recompile; xmonad --restart"),
    -- KB_GROUP Multimedia Keys
        ("<Print>",                spawn "flameshot gui"),
        ("<XF86AudioLowerVolume>", spawn "amixer -D pulse sset Master 1%- unmute | audioxob"),
        ("<XF86AudioMute>",        spawn "amixer -D pulse sset Master toggle | audioxob"),
        ("<XF86AudioNext>",        spawn "playerctl next"),
        ("<XF86AudioPlay>",        spawn "playerctl play-pause"),
        ("<XF86AudioPrev>",        spawn "playerctl previous"),
        ("<XF86AudioRaiseVolume>", spawn "amixer -D pulse sset Master 1%+ unmute | audioxob"),
        ("<XF86AudioStop>",        spawn "playerctl stop"),
        ("<XF86MonBrightnessUp>",  spawn "change-brightness 5%+ | xob"),
        ("<XF86MonBrightnessDown>",  spawn "change-brightness 5%- | xob"),
        ("M-<Print>",              spawn "peek"),
    -- KB_GROUP TODO SORT OUT
        ("M-,",                    sendMessage (IncMasterN 1)),
        ("M-.",                    sendMessage (IncMasterN (-1))),
        ("M-<F10>",                spawn "launch_redshift --manual 2000"),
        ("M-<F11>",                spawn "launch_redshift --auto 6500:2500"),
        ("M-<F12>",                spawn "launch_redshift --kill"),
        ("M-<Return>",             windows W.swapMaster),
        ("M-<Tab>",                windows W.focusDown),
        ("M-S-f",                  spawn (myFileExplorer)),
        ("M-S-<Return>",           spawn (myTerminal)),
        ("M-S-<Space>",            sendMessage NextLayout),
        ("M-<Space>", sendMessage (MT.Toggle NBFULL) >> sendMessage ToggleStruts), -- Toggles noborder/full
        ("M-S-a",                  namedScratchpadAction scratchpads "authy"),
        ("M-S-b",                  namedScratchpadAction scratchpads "blueberry"),
        ("M-S-c",                  kill),
        ("M-S-d",                  spawn "dmenu_run"), -- app launcher
        ("M-S-h",                  namedScratchpadAction scratchpads "btop"),
        ("M-S-g",                  namedScratchpadAction scratchpads "ctop"),
        ("M-S-j",                  windows W.swapUp),
        ("M-S-k",                  windows W.swapDown),
        ("M-S-m",                  namedScratchpadAction scratchpads "spotify"),
        ("M-S-,",                  namedScratchpadAction scratchpads "mailspring"),
        ("M-S-n",                  namedScratchpadAction scratchpads "notion"),
        ("M-S-p",                  namedScratchpadAction scratchpads "1password"),
        ("M-S-q",                  kill),
        ("M-S-s",                  namedScratchpadAction scratchpads "slack"),
        ("M-S-t",                  namedScratchpadAction scratchpads "todo"),
        ("M-S-x",                  spawn "dm-tool lock"), -- lockscreen
        ("M-S-y",                  namedScratchpadAction scratchpads "terminal"),
        ("M-b",                    sendMessage ToggleStruts),
        ("M-d",                    spawn "albert show"),
        ("M-h",                    sendMessage Shrink),
        ("M-j",                    windows W.focusDown),
        ("M-k",                    windows W.focusUp),
        ("M-l",                    sendMessage Expand),
        ("M-m",                    windows W.focusMaster),
        ("M-n",                    refresh), -- resize windows to correct size
        ("M-t",                    withFocused $ windows . W.sink) -- put back into tiling
    ]
-- END_KEYS

-- MAIN

main :: IO ()
main = do
    -- Launching three instances of xmobar on their monitors.
    xmproc0 <- spawnPipe "xmobar -x 0 $HOME/.config/xmobar/xmobarrc-0"
    xmproc1 <- spawnPipe "xmobar -x 1 $HOME/.config/xmobar/xmobarrc-1"
        -- the xmonad, ya know...what the WM is named after!
    xmonad $ ewmh def
        { manageHook         = manageDocks <+> myManageHook
        , handleEventHook    = docksEventHook
                               -- Uncomment this line to enable fullscreen support on things like YouTube/Netflix.
                               -- This works perfect on SINGLE monitor systems. On multi-monitor systems,
                               -- it adds a border around the window if screen does not have focus. So, my solution
                               -- is to use a keybinding to toggle fullscreen noborders instead.  (M-<Space>)
                               <+> fullscreenEventHook
        , modMask            = myModMask
        , terminal           = myTerminal
        , startupHook        = myStartupHook
        , layoutHook         = showWName' myShowWNameTheme $ myLayoutHook
        , workspaces         = myWorkspaces
        , borderWidth        = myBorderWidth
        , normalBorderColor  = myNormColor
        , focusedBorderColor = myFocusColor
        , logHook = dynamicLogWithPP $ namedScratchpadFilterOutWorkspacePP $ xmobarPP
              -- the following variables beginning with 'pp' are settings for xmobar.
              { ppOutput = \x ->  hPutStrLn xmproc0 x -- xmobar on monitor 1
                                >> hPutStrLn xmproc1 x -- xmobar on monitor 2
                                              , ppCurrent = xmobarColor "#c792ea" "" . wrap "<box type=Bottom width=2 mb=2 color=#c792ea>" "</box>"         -- Current workspace
              , ppVisible = xmobarColor "#c792ea" "" . clickable              -- Visible but not current workspace
              , ppHidden = xmobarColor "#82AAFF" "" . wrap "<box type=Top width=2 mt=2 color=#82AAFF>" "</box>" . clickable -- Hidden workspaces
              , ppHiddenNoWindows = xmobarColor "#82AAFF" ""  . clickable     -- Hidden workspaces (no windows)
              , ppTitle = xmobarColor "#b3afc2" "" . shorten 60               -- Title of active window
              , ppSep =  "<fc=#666666> <fn=1>|</fn> </fc>"                    -- Separator character
              , ppUrgent = xmobarColor "#C45500" "" . wrap "!" "!"            -- Urgent workspace
              , ppExtras  = [windowCount]                                     -- # of windows current workspace
              , ppOrder  = \(ws:l:t:ex) -> [ws,l]++ex++[t]                    -- order of things in xmobar
              }
        } `additionalKeysP` myKeys
