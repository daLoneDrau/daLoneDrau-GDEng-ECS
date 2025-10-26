class_name GlobalUtils


#region ENTITY TYPES
enum EntityType {
	PC     	   = 1,
	ITEM   	   = 2,
	NPC    	   = 4,
	GOLD   	   = 8,
	SCRIPTABLE = 16,
	UNIQUE 	   = 1024
}
#endregion ENTITY TYPES

#region PLAYER FLAGS
enum PlayerFlag {
	NO_MANA_DRAIN 	= 1,
	INVULNERABILITY = 2,
}
#endregion PLAYER FLAGS

#region EQUIPMENT CONSTANTS

#region WEAPON TYPES
# - used to determine animations to play
enum WeaponType {
	BARE   	  = 0,
	DAGGER 	  = 1,
	ONE_H  	  = 2,
	TWO_H  	  = 3,
	BOW    	  = 4,
	THROWABLE = 5,
}
#endregion WEAPON TYPES

#region OBJECT TYPES
enum ObjectType {
	WEAPON 	 	  = 1,
	DAGGER 	 	  = 2,
	ONE_H 	 	  = 4,
	TWO_H 	 	  = 8,
	BOW 		  = 16,
	SHIELD 	 	  = 32,
	FOOD 		  = 64,
	GOLD 	 	  = 128,
	ARMOR 	 	  = 256,
	HELMET 	 	  = 512,
	RING 	 	  = 1024,
	LEGGINGS 	  = 2048,
	GLOVES   	  = 4096,
	MISCELLANEOUS = 8192,
	AMULET		  = 16384,
}
#endregion OBJECT TYPES

#region EQUIPMENT SLOTS
enum EquipmentSlot {
	RING_LEFT  = 1,
	RING_RIGHT = 2,
	WEAPON 	   = 3,
	SHIELD 	   = 4,
	TORCH 	   = 5,
	ARMOR 	   = 6,
	HELMET 	   = 7,
	LEGGINGS   = 8,
	NECK	   = 9,
	GAUNTLETS  = 10,
}
#endregion EQUIPMENT SLOTS
#endregion EQUIPMENT CONSTANTS

#region MATH_CONSTANTS
const DIV_2: float = 0.5

const DIV_3: float = 0.3333

const DIV_5: float = 0.2

const DIV_6: float = 0.1667

const DIV_8: float = 0.125

const DIV_TWO_THIRDS: float = 0.6667
#endregion MATH_CONSTANTS

#region SCRIPTING
enum ScriptMessageAudience {
	SINGLE_ENTITY,
	ALL_ENTITIES,
	ENTITY_GROUP,
}

#region SCRIPT_VARIABLE_TYPES
enum ScriptVariableType {
	## flag indicating the script variable is a local string.
	TEXT = 8,
	## flag indicating the script variable is a local string array.
	TEXT_ARR = 9,
	## flag indicating the script variable is a local floating-potype.
	FLOAT = 10,
	## flag indicating the script variable is a local floating-poarray.
	FLOAT_ARR = 11,
	## flag indicating the script variable is a local integer.
	INT = 12,
	## flag indicating the script variable is a local integer array.
	INT_ARR = 13,
	## flag indicating the script variable is a local integer.
	LONG = 14,
	## flag indicating the script variable is a local long array.
	LONG_ARR = 15,
	BOOL = 16,
	BOOL_ARR = 17,
	DICTIONARY = 18,
}
#endregion SCRIPT_VARIABLE_TYPES

#region SCRIPT_MESSAGES
const SM_NULL: int = 0
const SM_INIT: int = 1
const SM_INVENTORYIN: int = 2
const SM_INVENTORYOUT: int = 3
const SM_INVENTORYUSE: int = 4
const SM_SCENEUSE: int = 5
const SM_EQUIPIN: int = 6
const SM_EQUIPOUT: int = 7
const SM_MAIN: int = 8
const SM_RESET: int = 9
const SM_CHAT: int = 10
const SM_ACTION: int = 11
const SM_DEAD: int = 12
const SM_REACHEDTARGET: int = 13
const SM_FIGHT: int = 14
const SM_FLEE: int = 15
const SM_HIT: int = 16
const SM_DIE: int = 17
const SM_LOSTTARGET: int = 18
const SM_TREATIN: int = 19
const SM_TREATOUT: int = 20
const SM_MOVE: int = 21
const SM_DETECTPLAYER: int = 22
const SM_UNDETECTPLAYER: int = 23
const SM_COMBINE: int = 24
const SM_NPC_FOLLOW: int = 25
const SM_NPC_FIGHT: int = 26
const SM_NPC_STAY: int = 27
const SM_INVENTORY2_OPEN: int = 28
const SM_INVENTORY2_CLOSE: int = 29
const SM_CUSTOM: int = 30
const SM_ENTER_ZONE: int = 31
const SM_LEAVE_ZONE: int = 32
const SM_INITEND: int = 33
const SM_CLICKED: int = 34
const SM_INSIDEZONE: int = 35
const SM_CONTROLLEDZONE_INSIDE: int = 36
const SM_LEAVEZONE: int = 37
const SM_CONTROLLEDZONE_LEAVE: int = 38
const SM_ENTERZONE: int = 39
const SM_CONTROLLEDZONE_ENTER: int = 40
const SM_LOAD: int = 41
const SM_SPELLCAST: int = 42
const SM_RELOAD: int = 43
const SM_COLLIDE_DOOR: int = 44
const SM_OUCH: int = 45
const SM_HEAR: int = 46
const SM_SUMMONED: int = 47
const SM_SPELLEND: int = 48
const SM_SPELLDECISION: int = 49
const SM_STRIKE: int = 50
const SM_COLLISION_ERROR: int = 51
const SM_WAYPOINT: int = 52
const SM_PATHEND: int = 53
const SM_CRITICAL: int = 54
const SM_COLLIDE_NPC: int = 55
const SM_BACKSTAB: int = 56
const SM_AGGRESSION: int = 57
const SM_COLLISION_ERROR_DETAIL: int = 58
const SM_GAME_READY: int = 59
const SM_CINE_END: int = 60
const SM_KEY_PRESSED: int = 61
const SM_CONTROLS_ON: int = 62
const SM_CONTROLS_OFF: int = 63
const SM_PATHFINDER_FAILURE: int = 64
const SM_PATHFINDER_SUCCESS: int = 65
const SM_TRAP_DISARMED: int = 66
const SM_BOOK_OPEN: int = 67
const SM_BOOK_CLOSE: int = 68
const SM_IDENTIFY: int = 69
const SM_BREAK: int = 70
const SM_STEAL: int = 71
const SM_COLLIDE_FIELD: int = 72
const SM_CURSORMODE: int = 73
const SM_EXPLORATIONMODE: int = 74
const SM_MAXCMD: int = 75
const SM_TURN_START: int = 76
const SM_TURN_END: int = 77
const SM_TARGET_DEATH: int = 78
const SM_EXECUTELINE: int = 255
const SM_DUMMY: int = 256
#endregion SCRIPT_MESSAGES
#endregion SCRIPTING

const TARGET_INFO: String = "PLAYER"


## Formats a number.
static func number_format(val: Variant, _decimals = 0, _dec_point = ".", _thousands_sep = ",") -> String:
	var number: float = float(val)

	if !_dec_point or !_thousands_sep:
		_dec_point = '.';
		_thousands_sep = ','


	var roundedNumber: String  = str(round( abs( number ) * float('1e' + str(_decimals)) ))
	var numbersString: String  = roundedNumber
	var decimalsString: String = ""
	if _decimals > 0:
		numbersString = roundedNumber.left(roundedNumber.length() - _decimals)
		decimalsString = roundedNumber.right(roundedNumber.length() - _decimals)

	var formattedNumber: String = ""

	while numbersString.length() > 3:
		formattedNumber += _thousands_sep + numbersString.right(3)
		numbersString = numbersString.substr(0, numbersString.length() - 3);

	var ret: String = ""
	if number < 0:
		ret += "-"
	ret += numbersString + formattedNumber
	if decimalsString != "":
		ret += (_dec_point + decimalsString)

	return ret
