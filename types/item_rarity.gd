class_name ItemRarity

enum Enum {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	ARTIFACT, # story/unique
}

static func as_string(v: Enum) -> String:
	return ["Common","Uncommon","Rare","Epic","Legendary","Artifact"][int(v)]
