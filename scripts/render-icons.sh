#!/bin/sh
#
# Makes the app icon and menu bar icon PNGs from the SVGs in design/.
# Needs rsvg-convert and ImageMagick: brew install librsvg imagemagick
#

set -eu

cd "$(dirname "$0")/.."

assets=Oriel/Assets.xcassets

# The app icon must have no transparent parts. macOS 26 cuts
# the rounded shape itself, and puts icons with a transparent
# edge on a gray background.
render_app_icon() {
    rsvg-convert -w "$2" -h "$2" design/app-icon.svg \
        | magick - -background "#11143A" -flatten -alpha off "$assets/AppIcon.appiconset/$1"
}

render_app_icon icon_16x16.png 16
render_app_icon icon_16x16@2x.png 32
render_app_icon icon_32x32.png 32
render_app_icon icon_32x32@2x.png 64
render_app_icon icon_128x128.png 128
render_app_icon icon_128x128@2x.png 256
render_app_icon icon_256x256.png 256
render_app_icon icon_256x256@2x.png 512
render_app_icon icon_512x512.png 512
render_app_icon icon_512x512@2x.png 1024

rsvg-convert -w 18 -h 18 design/menu-bar-icon.svg -o "$assets/MenuBarIcon.imageset/menu-bar-icon.png"
rsvg-convert -w 36 -h 36 design/menu-bar-icon.svg -o "$assets/MenuBarIcon.imageset/menu-bar-icon@2x.png"
