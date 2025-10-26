# res://ecs/components/PartyWalletComponent.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Shared currency and resource pool for a party entity.
## Acts as the group's collective wallet.
## Pure data; no logic or signals.
class_name PartyWalletComponent
extends EntityComponent

## —————————————————————————————————————————————
#region Currencies
## —————————————————————————————————————————————
@export var gold: int = 0
@export var silver: int = 0
@export var copper: int = 0
@export var gems_value: float = 0.0
@export var trade_credits: float = 0.0

#endregion

## —————————————————————————————————————————————
#region Shared Resources
## —————————————————————————————————————————————
@export var provisions: int = 0            # Food supplies or rations
@export var reagents: int = 0              # Magic reagents shared pool
@export var caravan_supplies: int = 0      # Transport/pack animal resources

#endregion

## —————————————————————————————————————————————
#region Meta
## —————————————————————————————————————————————
@export var linked_party_id: StringName = &""   # Connects to PartyComponent.party_id
@export var last_transaction_timestamp: float = 0.0
@export var total_earned: float = 0.0
@export var total_spent: float = 0.0

#endregion
