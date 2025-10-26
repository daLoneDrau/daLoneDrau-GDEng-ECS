# res://ecs/systems/economy/BaseEconomySystem.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Abstract economy API for deposits, withdrawals, transfers,
## conversions, vendor pricing, and currency formatting.
## Extend this class to create concrete implementations.
@abstract class_name BaseEconomySystem
extends GameSystem


## —————————————————————————————————————————————
#region Abstract Interface (must override)
## —————————————————————————————————————————————

# Checks whether the entity or its party can afford the given cost.
@abstract func can_afford(em: EntityManager, entity_id: StringName, cost_gold: int, party_id: StringName = &"") -> bool

# Attempts to withdraw the specified cost from appropriate wallets.
@abstract func withdraw(em: EntityManager, entity_id: StringName, cost_gold: int, party_id: StringName = &"") -> bool

# Deposits an amount into the appropriate wallet(s).
@abstract func deposit(em: EntityManager, entity_id: StringName, amount_gold: int, party_id: StringName = &"") -> void

# Transfers gold between wallets (entities or parties).
@abstract func transfer(em: EntityManager, from_entity: StringName, to_entity: StringName, amount_gold: int, from_party_id: StringName = &"", to_party_id: StringName = &"") -> bool

# Converts multi-currency values (gold/silver/copper) into canonical gold units.
@abstract func to_gold_units(gold: int, silver: int, copper: int) -> int

# Converts appraised or abstract value (e.g., gems, trade credits) into gold units.
@abstract func appraise_to_gold(value: float) -> int

# Returns a user-facing formatted string (e.g., "123g" or "12.5 gold").
@abstract func format_currency(gold: int) -> String

# Returns a dictionary breaking down total_gold into multi-currency denominations.
# Example: { "gold": 3, "silver": 5, "copper": 8 }
@abstract func breakdown_cost_to_multi_currency(total_gold: int) -> Dictionary

# Applies vendor modifiers (discounts, taxes, faction multipliers, etc.).
@abstract func apply_vendor_modifier(faction_id: StringName, base_cost_gold: int) -> int

#endregion


## —————————————————————————————————————————————
#region Optional Hooks
## —————————————————————————————————————————————

# Called after any wallet is mutated (extend to log analytics or timestamp).
@abstract func did_mutate_wallet(_em: EntityManager, _wallet: EntityComponent) -> void

#endregion


## —————————————————————————————————————————————
#region Protected Helpers (shared logic)
## —————————————————————————————————————————————

# Fetches a personal wallet for an entity.
func _get_personal_wallet(em: EntityManager, entity_id: StringName) -> WalletComponent:
	if em == null or entity_id == &"": return null
	return em.get_component(entity_id, WalletComponent)

# Fetches a party wallet given a party_id (matches PartyWalletComponent.linked_party_id).
@abstract func _get_party_wallet_by_id(em: EntityManager, party_id: StringName) -> PartyWalletComponent
# sample implementation
#	if em == null or party_id == &"": return null
#	var wallets: Array[Entity] = em.query([PartyWalletComponent])
#	for ent in wallets:
#		var w: PartyWalletComponent = ent.get_component("PartyWalletComponent")
#		if w and w.linked_party_id == party_id:
#			return w
#	return null

# Safe integer addition (clamped; overflow guard).
func _safe_add(a: int, b: int, max_val: int = 0x7FFFFFFF) -> int:
	var res := a + b
	if res < a: res = max_val
	return min(res, max_val)

# Safe integer subtraction (no negative results).
func _safe_sub(a: int, b: int) -> int:
	return max(a - b, 0)

# Touches wallet timestamps, if defined.
func _touch_wallet(wallet) -> void:
	if wallet == null: return
	if wallet.has_variable("last_transaction_timestamp"):
		wallet.last_transaction_timestamp = Time.get_unix_time_from_system()

# Helper to return a standard breakdown dictionary.
func _mk_breakdown(g: int, s: int, c: int) -> Dictionary:
	return { "gold": max(g, 0), "silver": max(s, 0), "copper": max(c, 0) }

#endregion

## —————————————————————————————————————————————
#region Pricing
## —————————————————————————————————————————————

# Base price (in gold units) for an item. Concrete systems decide where this
# comes from (ItemComponent, ItemDB, vendor table, rarity curve, etc).
func _get_item_value(item_id: StringName) -> float:
	var ret_val: float = 0.0
	var item := _get_item_component(item_id)
	if item != null:
		ret_val = item.price

		# if multiple currencies are used, such as copper, silver, or gold coins, build up the code below
		# var value_gold: float = 0.0
#		if item.has("base_value_gold"):
#			value_gold = float(item.base_value_gold)
#		elif item.has("base_value_silver"):
#			value_gold = float(item.base_value_silver) / SILVER_PER_GOLD
#		elif item.has("base_value_copper"):
#			value_gold = float(item.base_value_copper) / COPPER_PER_GOLD
#		else:
#			value_gold = 0.0

	return ret_val

# Helper: compute final vendor price and return a UI-ready breakdown.
# Returns:
# {
#   "base_gold": int,      # base price before vendor modifier
#   "final_gold": int,     # final price after modifier
#   "breakdown": { "gold": int, "silver": int, "copper": int }  # final_gold broken down
# }
func _get_item_value_with_vendor(item_id: StringName, faction_id: StringName) -> Dictionary:
	var base_gold: int = max(_get_item_value(item_id), 0)
	var final_gold: int = max(apply_vendor_modifier(faction_id, base_gold), 0)
	var bd: Dictionary = breakdown_cost_to_multi_currency(final_gold)
	return {
		"base_gold": base_gold,
		"final_gold": final_gold,
		"breakdown": bd
	}


@abstract func _get_party_id(character_id: StringName) -> StringName
@abstract func _gold_units_party(party_id: StringName) -> int
@abstract func _gold_units_wallet(character_id: StringName) -> int
@abstract func _dec_party_gold(party_id: StringName, amount: int) -> void
@abstract func _dec_wallet_gold(character_id: StringName, amount: int) -> void
@abstract func _inc_party_gold(party_id: StringName, amount: int) -> void
@abstract func _inc_wallet_gold(character_id: StringName, amount: int) -> void
@abstract func _get_item_sell_value(item_id: StringName) -> float

## —————————————————————————————————————————————
#region Component Fetchers
## —————————————————————————————————————————————


@abstract func _get_item_component(item_id: StringName) -> ItemComponent
#   var item: ItemComponent = _entity_manager.get_component(item_id, ItemComponent) as ItemComponent
#	return item

@abstract func _get_inventory_component(entity_id: StringName) -> InventoryComponent
#   var inv: InventoryComponent = _entity_manager.get_component(entity_id, InventoryComponent) as InventoryComponent
#	return inv

@abstract func _get_party_component(entity_id: StringName) -> PartyComponent
#   var inv: InventoryComponent = _entity_manager.get_component(entity_id, InventoryComponent) as InventoryComponent
#	return inv


@abstract func _get_wallet(entity_id: StringName)
#   return entity_manager.get_component(entity_id, WalletComponent)

@abstract func _get_party_wallet(party_id: StringName)
#   return entity_manager.get_component(party_id, PartyWalletComponent)

#endregion
