# res://ecs/components/WalletComponent.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Tracks currency and wealth values for a single entity
## (player, NPC, merchant, etc.). Pure data; no logic.
class_name WalletComponent
extends EntityComponent

## —————————————————————————————————————————————
#region Balances
## —————————————————————————————————————————————
@export var gold: int = 0                  # Base currency
@export var silver: int = 0                # Optional subunit
@export var copper: int = 0                # Optional subunit
@export var gems_value: float = 0.0        # Appraised value of gems/jewels
@export var trade_credits: float = 0.0     # Faction or merchant credit

#endregion

## —————————————————————————————————————————————
#region Meta
## —————————————————————————————————————————————
@export var last_transaction_timestamp: float = 0.0
@export var total_earned: float = 0.0
@export var total_spent: float = 0.0

#endregion
