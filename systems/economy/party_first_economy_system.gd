# res://ecs/systems/economy/PartyFirstEconomySystem.gd
@abstract class_name PartyFirstEconomySystem
extends BaseEconomySystem


signal payment_failed(context: Dictionary)
signal purchase_completed(buyer: StringName, seller: StringName, item_id: StringName, count: int, total_price_gold: int)
signal wallet_changed(party_id: StringName)
signal sale_completed(seller: StringName, vendor: StringName, item_id: StringName, num_removed: int, payout: int)


## —————————————————————————————————————————————
#region System References. will be set in concrete implementations using Autoload instances
## —————————————————————————————————————————————

## the [EntityManager] instance
var _entity_manager: EntityManager

## the [InventorySystem] instance
var _inventory_system: InventorySystem

## the [PlayerSystem] instance
var _player_system: PlayerSystem

## the [ScriptSystem] instance
var _script_system: ScriptSystem

#endregion)


const SILVER_PER_GOLD: int = 10
const COPPER_PER_SILVER: int = 10
const COPPER_PER_GOLD: int = SILVER_PER_GOLD * COPPER_PER_SILVER # 100

## Currency conversion & appraisal ---------------------------------------
func to_gold_units(gold: int, silver: int, copper: int) -> int:
	var total_copper := (gold * COPPER_PER_GOLD) + (silver * COPPER_PER_SILVER) + copper
	return int(total_copper / COPPER_PER_GOLD)

func appraise_to_gold(value: float) -> int:
	return int(round(value))

func breakdown_cost_to_multi_currency(total_gold: int) -> Dictionary:
	return _mk_breakdown(max(total_gold, 0), 0, 0)  # all in gold by default

func format_currency(gold: int) -> String:
	return str(gold, "g")

## Vendor pricing ----------------------------------------------------------
func apply_vendor_modifier(faction_id: StringName, base_cost_gold: int) -> int:
	var mult := _vendor_multiplier_for_faction(faction_id)
	var modified := int(round(float(max(base_cost_gold, 0)) * mult))
	return max(modified, 0)

func _vendor_multiplier_for_faction(faction_id: StringName) -> float:
	match String(faction_id):
		"MERCHANTS_GUILD":  return 0.95
		"BLACK_MARKET":     return 1.10
		"PRIESTHOOD":       return 0.90
		_:                  return 1.00

## NEW: base price lookup --------------------------------------------------
func price_item(em: EntityManager, item_id: StringName) -> int:
	if em == null or item_id == &"":
		return 0
	# Strategy A: read from ItemComponent on the item entity
	var ic: ItemComponent = em.get_component(item_id, ItemComponent)
	if ic and ic.has_variable("base_price"):
		return int(max(ic.base_price, 0))
	# Strategy B: fall back to 0 if not found (override in another concrete class)
	return 0

## Affordance & mutations --------------------------------------------------
func can_afford(em: EntityManager, entity_id: StringName, cost_gold: int, party_id: StringName = &"") -> bool:
	if cost_gold <= 0:
		return true
	var party_w := _get_party_wallet_by_id(em, party_id)
	var personal_w := _get_personal_wallet(em, entity_id)
	var party_gold := party_w.gold if party_w else 0
	var personal_gold := personal_w.gold if personal_w else 0
	return (party_gold + personal_gold) >= cost_gold

func withdraw(em: EntityManager, entity_id: StringName, cost_gold: int, party_id: StringName = &"") -> bool:
	if cost_gold <= 0:
		return true
	var party_w := _get_party_wallet_by_id(em, party_id)
	var personal_w := _get_personal_wallet(em, entity_id)
	var remaining := cost_gold

	if party_w and party_w.gold > 0:
		var take = min(party_w.gold, remaining)
		party_w.gold = _safe_sub(party_w.gold, take)
		remaining -= take
		_touch_wallet(party_w)
		did_mutate_wallet(em, party_w)

	if remaining > 0 and personal_w and personal_w.gold > 0:
		var take = min(personal_w.gold, remaining)
		personal_w.gold = _safe_sub(personal_w.gold, take)
		remaining -= take
		_touch_wallet(personal_w)
		did_mutate_wallet(em, personal_w)

	return remaining == 0

func deposit(em: EntityManager, entity_id: StringName, amount_gold: int, party_id: StringName = &"") -> void:
	if amount_gold <= 0:
		return
	var party_w := _get_party_wallet_by_id(em, party_id)
	if party_w:
		party_w.gold = _safe_add(party_w.gold, amount_gold)
		_touch_wallet(party_w)
		did_mutate_wallet(em, party_w)
		return
	var personal_w := _get_personal_wallet(em, entity_id)
	if personal_w:
		personal_w.gold = _safe_add(personal_w.gold, amount_gold)
		_touch_wallet(personal_w)
		did_mutate_wallet(em, personal_w)

func transfer(
	em: EntityManager,
	from_entity: StringName,
	to_entity: StringName,
	amount_gold: int,
	from_party_id: StringName = &"",
	to_party_id: StringName = &""
) -> bool:
	if amount_gold <= 0:
		return true

	var src_party := _get_party_wallet_by_id(em, from_party_id)
	var dst_party := _get_party_wallet_by_id(em, to_party_id)
	var src_personal := _get_personal_wallet(em, from_entity)
	var dst_personal := _get_personal_wallet(em, to_entity)

	var src = src_party if src_party else src_personal
	var dst = dst_party if dst_party else dst_personal
	if src == null or dst == null:
		return false
	if src.gold < amount_gold:
		return false

	src.gold = _safe_sub(src.gold, amount_gold)
	dst.gold = _safe_add(dst.gold, amount_gold)
	_touch_wallet(src)
	_touch_wallet(dst)
	did_mutate_wallet(em, src)
	did_mutate_wallet(em, dst)
	return true

@abstract func _seller_faction(seller: StringName) -> StringName

# In PartyFirstEconomySystem.gd (or Shop/Economy façade)
func buy_item_party_first(buyer: StringName, seller: StringName, item_id: StringName, count := 1) -> Dictionary:
	# 1) Price
	var unit_price := appraise_to_gold(_get_item_value(item_id))         # implement _get_item_value
	var price := apply_vendor_modifier(_seller_faction(seller), unit_price) * count
	var total_price_gold: int = max(price, 0)

	# 2) Pay (party first; then buyer wallet fallback)
	var paid := _pay_party_first(buyer, total_price_gold)
	if not paid.ok:
		payment_failed.emit({
			"reason": &"insufficient_funds",
			"buyer": buyer, "seller": seller,
			"item_id": item_id, "count": count,
			"required": total_price_gold, "available": paid.available
		})
		return paid

	# 3) Deliver goods (Inventory)
	var inv_res := _inventory_system.add_item(buyer, item_id, count)
	if not inv_res.get("ok", false):
		# 4) Rollback payment if inventory add failed
		_refund_party_first(buyer, total_price_gold)
		return { "ok": false, "reason": &"inventory_no_space", "price": total_price_gold, "inv": inv_res }

	purchase_completed.emit(buyer, seller, item_id, count, total_price_gold)
	return { "ok": true, "reason": &"purchased", "price": total_price_gold, "placements": inv_res.get("placements", []) }


func _pay_party_first(character_id: StringName, cost_gold: int) -> Dictionary:
	var party_id := _get_party_id(character_id)  # your PartyComponent logic
	var available_party := _gold_units_party(party_id)
	var available_char  := _gold_units_wallet(character_id)
	var available_total := available_party + available_char

	if available_total < cost_gold:
		return { "ok": false, "reason": &"insufficient_funds", "available": available_total }

	var remaining := cost_gold

	# 1) draw from party
	if available_party > 0:
		var draw_party: int = min(remaining, available_party)
		_dec_party_gold(party_id, draw_party)
		remaining -= draw_party
		wallet_changed.emit(party_id)

	# 2) draw remainder from character
	if remaining > 0:
		_dec_wallet_gold(character_id, remaining)
		wallet_changed.emit(character_id)
		remaining = 0

	return { "ok": true, "paid": cost_gold }


func _refund_party_first(character_id: StringName, amount_gold: int) -> void:
	var party_id := _get_party_id(character_id)
	_inc_party_gold(party_id, amount_gold)  # simplest policy: all refunds back to party
	wallet_changed.emit(party_id)


func sell_item_to_vendor(seller: StringName, vendor: StringName, item_id: StringName, count := 1) -> Dictionary:
	# 1) Remove item(s) from seller inventory
	var rem := _inventory_system.remove_item(seller, item_id, count)
	if not rem.get("ok", false):
		return rem

	# 2) Appraise payout
	var unit_price: int = appraise_to_gold(_get_item_sell_value(item_id))     # sell value may differ from buy
	var payout: int = max(unit_price * int(rem.get("removed", 0)), 0)

	# 3) Credit: party-first (or to seller wallet if single-player)
	_inc_party_gold(_get_party_id(seller), payout)
	wallet_changed.emit(_get_party_id(seller))

	sale_completed.emit(seller, vendor, item_id, int(rem.get("removed", 0)), payout)
	return { "ok": true, "reason": &"sold", "payout": payout }


var _escrows := {}  # tx_id -> {party_id, actor_id, party_draw, actor_draw, total}

func _open_escrow(tx_id: int, party_id: StringName, actor_id: StringName, needed: int) -> Dictionary:
	var party_av := _gold_units_party(party_id)
	var actor_av := _gold_units_wallet(actor_id)
	var take_party: int = min(needed, party_av)
	var take_actor := needed - take_party
	if take_actor > actor_av: return { "ok": false, "reason": &"insufficient_funds" }

	_dec_party_gold(party_id, take_party)
	_dec_wallet_gold(actor_id, take_actor)
	_escrows[tx_id] = { "party_id": party_id, "actor_id": actor_id, "party_draw": take_party, "actor_draw": take_actor, "total": needed }
	return { "ok": true }


func _refund_escrow(tx_id: int) -> void:
	var e = _escrows.get(tx_id, null)
	if e == null: return
	_inc_party_gold(e.party_id, e.party_draw)
	_inc_wallet_gold(e.actor_id, e.actor_draw)
	_escrows.erase(tx_id)

