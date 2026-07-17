class_name DamageCalculator
extends RefCounted


static func calculate(base_damage: float, multiplier: float = 1.0, flat_bonus: float = 0.0, defense: float = 0.0) -> float:
	var raw_damage := maxf(base_damage * multiplier + flat_bonus, 0.0)
	var mitigation := 100.0 / (100.0 + maxf(defense, 0.0))
	return maxf(raw_damage * mitigation, 0.0)
