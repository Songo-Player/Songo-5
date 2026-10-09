#!/usr/bin/env sh
# Builds assets/fonts/NotoSansCJKjp-Medium.otf (the font the themes use) as a
# subset of the full font in this folder. This folder has a .gdignore, so the
# full 16MB font is never imported or exported by Godot.
#
# Kept: Latin + Latin extended, Greek, Cyrillic, general punctuation/symbols,
# CJK punctuation, hiragana, katakana, half/full-width forms, and every
# character in JIS X 0208 (all JIS Level 1 + Level 2 kanji plus its symbols).
# Dropped: Hangul and the rarer CJK ideographs outside JIS X 0208.
#
# Requires fonttools (pyftsubset). Run from anywhere:
#   sh assets/fonts/source/subset_noto_cjk.sh
set -e
cd "$(dirname "$0")"

python3 - > unicodes.txt <<'EOF'
ranges = [
    (0x0020, 0x024F),  # Basic Latin, Latin-1, Latin Extended-A/B
    (0x0370, 0x03FF),  # Greek
    (0x0400, 0x04FF),  # Cyrillic
    (0x1E00, 0x1EFF),  # Latin Extended Additional
    (0x2000, 0x206F),  # General Punctuation
    (0x2070, 0x209F),  # Super/subscripts
    (0x20A0, 0x20CF),  # Currency
    (0x2100, 0x218F),  # Letterlike, number forms
    (0x2190, 0x21FF),  # Arrows
    (0x2460, 0x24FF),  # Enclosed alphanumerics
    (0x2500, 0x25FF),  # Box drawing, block elements, geometric shapes
    (0x2600, 0x26FF),  # Misc symbols
    (0x266A, 0x266F),  # Music notes
    (0x3000, 0x303F),  # CJK Symbols and Punctuation
    (0x3040, 0x30FF),  # Hiragana, Katakana
    (0x31F0, 0x31FF),  # Katakana Phonetic Extensions
    (0xFF00, 0xFFEF),  # Half/full-width forms
]
codes = set()
for lo, hi in ranges:
    codes.update(range(lo, hi + 1))
# Every character in JIS X 0208 (rows 1-84), decoded through EUC-JP.
for row in range(1, 85):
    for cell in range(1, 95):
        try:
            codes.add(ord(bytes([0xA0 + row, 0xA0 + cell]).decode("euc_jp")))
        except UnicodeDecodeError:
            pass
print(",".join("U+%04X" % c for c in sorted(codes)))
EOF

pyftsubset NotoSansCJKjp-Medium.otf \
    --unicodes-file=unicodes.txt \
    --output-file=../NotoSansCJKjp-Medium.otf
rm unicodes.txt
ls -l NotoSansCJKjp-Medium.otf ../NotoSansCJKjp-Medium.otf
