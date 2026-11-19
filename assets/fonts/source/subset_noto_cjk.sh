#!/usr/bin/env sh
# Builds the fonts the app uses from the full font in this folder:
#  - assets/fonts/NotoSansCJKjp-Medium-Latin.otf, the font the themes use. Latin,
#    Greek, Cyrillic and symbols only, so it's small and quick to load at boot.
#  - assets/fonts/NotoSansCJKjp-Medium.otf, a copy of the full font (kanji, kana,
#    Hangul). Nothing loads it at boot: utilities/cjk_font.gd attaches it as the
#    Latin font's fallback the first time CJK text turns up.
# This folder has a .gdignore, so Godot never imports or exports the copy in here.
#
# Requires fonttools (pyftsubset). Run from anywhere:
#   sh assets/fonts/source/subset_noto_cjk.sh
set -e
cd "$(dirname "$0")"

cp NotoSansCJKjp-Medium.otf ../NotoSansCJKjp-Medium.otf

pyftsubset NotoSansCJKjp-Medium.otf \
    --unicodes="U+0020-024F,U+0370-03FF,U+0400-04FF,U+1E00-1EFF,U+2000-206F,U+2070-209F,U+20A0-20CF,U+2100-218F,U+2190-21FF,U+2460-24FF,U+2500-25FF,U+2600-26FF" \
    --output-file=../NotoSansCJKjp-Medium-Latin.otf
ls -l NotoSansCJKjp-Medium.otf ../NotoSansCJKjp-Medium.otf ../NotoSansCJKjp-Medium-Latin.otf
