/obj/vehicle/sealed/mecha/combat/durand/shell
	desc = "An aging combat exosuit utilized by the Nanotrasen corporation, altered for autonomous control by circuits."
	name = "\improper Circutix"

/obj/vehicle/sealed/mecha/combat/durand/shell/Initialize()
	. = ..()
	AddComponent( \
		/datum/component/shell, \
		unremovable_circuit_components = list(new /obj/item/circuit_component/mech_movement, new /obj/item/circuit_component/mech_equipment), \
		capacity = SHELL_CAPACITY_LARGE, \
		shell_flags = SHELL_FLAG_ALLOW_FAILURE_ACTION \
	)

///Only exists to make porting a pain when any tg cooder realizes what a piece of shit this is
/obj/vehicle/sealed/mecha/combat/durand/shell/proc/attack_target(atom/target, params)
	SIGNAL_HANDLER
	var/obj/vehicle/sealed/mecha/self = src
	if(!isturf(target) && !isturf(target.loc)) // Prevents inventory from being drilled
		return
	if(self.completely_disabled || self.is_currently_ejecting || (self.mecha_flags & CANNOT_INTERACT))
		return
	//var/list/modifiers = params2list(params)
	if(!self.get_charge())
		return
	if(src == target)
		return
	var/dir_to_target = get_dir(src,target)
	if(dir_to_target && !(dir_to_target & dir))//wrong direction
		return
	if(self.internal_damage & MECHA_INT_CONTROL_LOST)
		target = pick(view(3,target))


	if(self.selected)
		if(!Adjacent(target) && (self.selected.range & MECHA_RANGED))
			if(SEND_SIGNAL(src, COMSIG_MECHA_EQUIPMENT_CLICK, src, target) & COMPONENT_CANCEL_EQUIPMENT_CLICK)
				return
			INVOKE_ASYNC(self.selected, /obj/item/mecha_parts/mecha_equipment.proc/action, src, target, params)
			return
		if((self.selected.range & MECHA_MELEE) && Adjacent(target))
			if(SEND_SIGNAL(src, COMSIG_MECHA_EQUIPMENT_CLICK, src, target) & COMPONENT_CANCEL_EQUIPMENT_CLICK)
				return
			INVOKE_ASYNC(self.selected, /obj/item/mecha_parts/mecha_equipment.proc/action, src, target, params)
			return
	var/on_cooldown = TIMER_COOLDOWN_CHECK(src, COOLDOWN_MECHA_MELEE_ATTACK)
	var/adjacent = Adjacent(target)

	var/mob/living/attacker = new /mob/living/
	attacker.combat_mode = TRUE

	if(SEND_SIGNAL(src, COMSIG_MECHA_MELEE_CLICK, attacker, target, on_cooldown, adjacent) & COMPONENT_CANCEL_MELEE_CLICK)
		qdel(attacker)
		return
	if(on_cooldown || !adjacent)
		qdel(attacker)
		return
	if(self.internal_damage & MECHA_INT_CONTROL_LOST)
		target = pick(oview(1,src))

	target.mech_melee_attack(src, attacker)
	qdel(attacker)
	TIMER_COOLDOWN_START(src, COOLDOWN_MECHA_MELEE_ATTACK, self.melee_cooldown)

/obj/item/circuit_component/mech_movement
	display_name = "Mech Movement"
	display_desc = "The movement interface with an mech."

	/// Called when attack_hand is called on the shell.
	//var/obj/machinery/door/airlock/attached_airlock
	var/obj/vehicle/sealed/mecha/combat/durand/attached_mech

	/// The inputs to allow for the drone to move
	var/datum/port/input/north
	var/datum/port/input/east
	var/datum/port/input/south
	var/datum/port/input/west

	// Done like this so that travelling diagonally is more simple
	COOLDOWN_DECLARE(north_delay)
	COOLDOWN_DECLARE(east_delay)
	COOLDOWN_DECLARE(south_delay)
	COOLDOWN_DECLARE(west_delay)

	/// Delay between each movement
	var/move_delay = 0.1 SECONDS

/obj/item/circuit_component/mech_movement/Initialize()
	. = ..()
	north = add_input_port("Move North", PORT_TYPE_SIGNAL)
	east = add_input_port("Move East", PORT_TYPE_SIGNAL)
	south = add_input_port("Move South", PORT_TYPE_SIGNAL)
	west = add_input_port("Move West", PORT_TYPE_SIGNAL)


/obj/item/circuit_component/mech_movement/register_shell(atom/movable/shell)
	. = ..()
	if(istype(shell, /obj/vehicle/sealed/mecha/combat/durand/shell))
		attached_mech = shell
		//RegisterSignal(shell, COMSIG_AIRLOCK_SET_BOLT, .proc/on_airlock_set_bolted)
		//RegisterSignal(shell, COMSIG_AIRLOCK_OPEN, .proc/on_airlock_open)
		//RegisterSignal(shell, COMSIG_AIRLOCK_CLOSE, .proc/on_airlock_closed)

/obj/item/circuit_component/mech_movement/Destroy()
	north = null
	east = null
	south = null
	west = null
	return ..()

/obj/item/circuit_component/mech_movement/input_received(datum/port/input/port)
	. = ..()
	if(.)
		return

	if(!attached_mech)
		return

	var/direction

	if(COMPONENT_TRIGGERED_BY(north, port) && COOLDOWN_FINISHED(src, north_delay))
		direction = NORTH
		COOLDOWN_START(src, north_delay, move_delay)
	else if(COMPONENT_TRIGGERED_BY(east, port) && COOLDOWN_FINISHED(src, east_delay))
		direction = EAST
		COOLDOWN_START(src, east_delay, move_delay)
	else if(COMPONENT_TRIGGERED_BY(south, port) && COOLDOWN_FINISHED(src, south_delay))
		direction = SOUTH
		COOLDOWN_START(src, south_delay, move_delay)
	else if(COMPONENT_TRIGGERED_BY(west, port) && COOLDOWN_FINISHED(src, west_delay))
		direction = WEST
		COOLDOWN_START(src, west_delay, move_delay)

	if(!direction)
		return

	//attached_mech.Move(direction)
	attached_mech.vehicle_move(direction)

/obj/item/circuit_component/mech_equipment
	display_name = "Mech Equipment"
	display_desc = "The equipment interface with an mech."

	/// Called when attack_hand is called on the shell.
	//var/obj/machinery/door/airlock/attached_airlock
	var/obj/vehicle/sealed/mecha/combat/durand/shell/attached_mech

	/// The inputs to allow for the drone to move
	var/datum/port/input/attack
	var/datum/port/input/target
	var/datum/port/input/change_equipment


/obj/item/circuit_component/mech_equipment/Initialize()
	. = ..()
	attack = add_input_port("Attack", PORT_TYPE_SIGNAL)
	target = add_input_port("Target", PORT_TYPE_ATOM)
	change_equipment = add_input_port("Switch Equipment", PORT_TYPE_SIGNAL)


/obj/item/circuit_component/mech_equipment/register_shell(atom/movable/shell)
	. = ..()
	if(istype(shell, /obj/vehicle/sealed/mecha/combat/durand/shell))
		attached_mech = shell

/obj/item/circuit_component/mech_equipment/Destroy()
	attack = null
	return ..()

/obj/item/circuit_component/mech_equipment/input_received(datum/port/input/port)
	. = ..()
	if(.)
		return

	if(!attached_mech)
		return
	if(COMPONENT_TRIGGERED_BY(attack, port))
		var/mob/tgt = target.input_value
		if(!tgt)
			return
		//INVOKE_ASYNC(attached_mech, /obj/vehicle/sealed/mechacombat/durand/shell.proc/attack_target, tgt, "")
		attached_mech.attack_target(tgt, "")

	if(COMPONENT_TRIGGERED_BY(change_equipment, port))
		var/list/available_equipment = list()
		for(var/e in attached_mech.equipment)
			var/obj/item/mecha_parts/mecha_equipment/equipment = e
			if(equipment.selectable)
				available_equipment += equipment
		if(!attached_mech.selected)
			attached_mech.selected = available_equipment[1]
			return
		var/number = 0
		for(var/equipment in available_equipment)
			number++
			if(equipment != attached_mech.selected)
				continue
			if(available_equipment.len == number)
				attached_mech.selected = null
			else
				attached_mech.selected = available_equipment[number+1]
			return
	

