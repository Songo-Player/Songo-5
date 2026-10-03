class_name SongoMusicRecord extends TagLibMusicRecord

# Songo-side extension of GDTagLib's native TagLibMusicRecord. GDTagLib always
# builds plain TagLibMusicRecords, so rather than instantiating this directly
# SongoData attaches this script to each record after an import (see adopt).
# The script reference is saved alongside the record in songo_data.res.

@export var times_listened: int = 0

## Lowercase file extension ("mp3", "flac", ...), or "stream" for network records.
var file_type: String:
	get: return "stream" if full_path.contains("://") else full_path.get_extension().to_lower()

## Upgrades a plain TagLibMusicRecord in place to a SongoMusicRecord. Keeps the
## same instance, so albums / artists / playlists referencing it stay valid.
static func adopt(record: TagLibMusicRecord) -> SongoMusicRecord:
	if not record is SongoMusicRecord:
		record.set_script(SongoMusicRecord)
	return record as SongoMusicRecord
