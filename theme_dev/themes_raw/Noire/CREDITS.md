# Noire — credits

## Fonts
**Limelight** — `assets/Limelight-Regular.ttf`
- Copyright 2010 Sorkin Type Co (www.sorkintype.com), with Reserved Font Name "Limelight".
- Licensed under the SIL Open Font License 1.1; full text in `assets/Limelight-OFL.txt`.
- From the Google Fonts repository: https://github.com/google/fonts/tree/main/ofl/limelight

**Special Elite** — `assets/SpecialElite-Regular.ttf`
- Copyright 2010 Brian J. Bonislawsky DBA Astigmatic (AOETI).
- Licensed under the Apache License 2.0; full text in `assets/SpecialElite-LICENSE.txt`.
- From the Google Fonts repository: https://github.com/google/fonts/tree/main/apache/specialelite
- Modified for Noire: the ascent (hhea and OS/2 tables) was raised to just under the Noto fallback's, so text sits centred in the boxes Godot sizes for it. Its legacy `kern` table was removed (kerning stays in GPOS), as Godot's fallback text server misplaces glyphs with it. Glyphs are unchanged.

CJK titles fall back to Songo#5's own Noto Sans CJK.

## Icons
The menu, list and player icons (`music.svg`, `record.svg`, `user.svg`,
`layergroup.svg`, `gear.svg`, `Play.svg`, `Pause.svg`, `shuffle.svg`,
`Repeat.svg`, `lock.svg`, `coffee.svg`) are Songo#5's own, used from
`res://assets/`. They aren't copied into this theme.

## Everything else
The room, blinds, rain and grain (`assets/atmosphere.gdshader`), the black
and white prints (`assets/silver_print.gdshader`), the deco frames and rules,
evidence photo and paperclip, rubber stamp, cigarette and smoke, film strip
and dot leaders are all drawn in code. The theme ships no image files
besides `preview.png`, which is a screenshot of the theme running.

Theme by Claude (Anthropic), made for Songo#5.
