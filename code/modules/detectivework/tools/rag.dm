/mob
	var/bloody_hands = null
	var/mob/living/carbon/human/bloody_hands_mob
	var/track_blood = 0
	var/list/feet_blood_DNA
	var/track_blood_type
	var/feet_blood_color

/obj/item/clothing/gloves
	var/transfer_blood = 0
	var/mob/living/carbon/human/bloody_hands_mob

/obj/item/clothing/shoes/
	var/track_blood = 0

/obj/item/weapon/reagent_containers/glass/rag
	name = "rag"
	desc = "For cleaning up messes, you suppose."
	w_class = 1
	icon = 'icons/obj/toy.dmi'
	icon_state = "rag"
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = list(5)
	volume = 10
	can_be_placed_into = null
	flags = OPENCONTAINER | NOBLUDGEON
	unacidable = 0

	var/on_fire = 0
	var/burn_time = 20 //if the rag burns for too long it turns to ashes
	drop_sound = 'sound/items/drop/clothing.ogg'

/obj/item/weapon/reagent_containers/glass/rag/Initialize()
	. = ..()
	update_name()

/obj/item/weapon/reagent_containers/glass/rag/Destroy()
	STOP_PROCESSING(SSprocessing, src) //so we don't continue turning to ash while gc'd
	return ..()

/obj/item/weapon/reagent_containers/glass/rag/attack_self(mob/user as mob)
	if(on_fire)
		user.visible_message("<span class='warning'>\The [user] stamps out [src].</span>", "<span class='warning'>You stamp out [src].</span>")
		user.unEquip(src)
		extinguish()
	else
		remove_contents(user)

/obj/item/weapon/reagent_containers/glass/rag/attackby(obj/item/W, mob/user)
	if(!on_fire && istype(W, /obj/item/weapon/flame))
		var/obj/item/weapon/flame/F = W
		if(F.lit)
			ignite()
			if(on_fire)
				visible_message("<span class='warning'>\The [user] lights [src] with [W].</span>")
			else
				to_chat(user, "<span class='warning'>You manage to singe [src], but fail to light it.</span>")

	. = ..()
	update_name()

/obj/item/weapon/reagent_containers/glass/rag/proc/update_name()
	if(on_fire)
		name = "burning [initial(name)]"
	else if(reagents.total_volume)
		name = "damp [initial(name)]"
	else
		name = "dry [initial(name)]"

/obj/item/weapon/reagent_containers/glass/rag/update_icon()
	if(on_fire)
		icon_state = "raglit"
	else
		icon_state = "rag"

	var/obj/item/weapon/reagent_containers/food/drinks/bottle/B = loc
	if(istype(B))
		B.update_icon()

/obj/item/weapon/reagent_containers/glass/rag/proc/remove_contents(mob/user, atom/trans_dest = null)
	if(!trans_dest && !user.loc)
		return

	if(reagents.total_volume)
		var/target_text = trans_dest? "\the [trans_dest]" : "\the [user.loc]"
		user.visible_message("<span class='danger'>\The [user] begins to wring out [src] over [target_text].</span>", "<span class='notice'>You begin to wring out [src] over [target_text].</span>")

		if(do_after(user, reagents.total_volume*5)) //50 for a fully soaked rag
			if(trans_dest)
				reagents.trans_to(trans_dest, reagents.total_volume)
			else
				reagents.splash(user.loc, reagents.total_volume)
			user.visible_message("<span class='danger'>\The [user] wrings out [src] over [target_text].</span>", "<span class='notice'>You finish to wringing out [src].</span>")
			update_name()

/obj/item/weapon/reagent_containers/glass/rag/proc/wipe_down(atom/A, mob/user)
	if(!reagents.total_volume)
		to_chat(user, "<span class='warning'>The [initial(name)] is dry!</span>")
	else
		user.visible_message("\The [user] starts to wipe down [A] with [src]!")
		reagents.splash(A, 1) //get a small amount of liquid on the thing we're wiping.
		update_name()
		if(do_after(user,30))
			user.visible_message("\The [user] finishes wiping off \the [A]!")
			A.clean_blood()

/obj/item/weapon/reagent_containers/glass/rag/attack(atom/target as obj|turf|area, mob/user as mob , flag)
	if(isliving(target))
		var/mob/living/M = target
		if(on_fire)
			user.visible_message("<span class='danger'>\The [user] hits [target] with [src]!</span>",)
			user.do_attack_animation(src)
			M.IgniteMob()
		else if(ishuman(M))
			var/mob/living/carbon/human/H = M
			var/obj/item/organ/external/affecting = H.get_organ(user.zone_sel.selecting)
			if(LAZYLEN(affecting.wounds))
				for (var/datum/wound/W in affecting.wounds)
					if (W.internal)
						continue
					if(W.bandaged || W.clamped)
						continue
					to_chat(user, span("notice", "You begin to bandage \a [W.desc] on [M]'s [affecting.name] with a rag."))
					if(!do_mob(user, M, W.damage/10)) // takes twice as long as a normal bandage
						to_chat(user, span("notice","You must stand still to bandage wounds."))
						break
					for(var/datum/reagent/R in reagents.reagent_list)
						var/strength = R.germ_adjust * R.volume/4
						if(istype(R, /datum/reagent/alcohol))
							var/datum/reagent/alcohol/A = R
							strength = strength * (A.strength/100)
						W.germ_level -= min(strength, W.germ_level)//Clean the wound a bit.
						if (W.germ_level <= 0)
							W.disinfected = 1//The wound becomes disinfected if fully cleaned
							break
					reagents.trans_to_mob(H, reagents.total_volume*0.75, CHEM_TOUCH) // most of it gets on the skin
					reagents.trans_to_mob(H, reagents.total_volume*0.25, CHEM_BLOOD) // some gets in the wound
					user.visible_message(span("notice", "\The [user] bandages \a [W.desc] on [M]'s [affecting.name] with a rag, tying it in place."), \
					                     span("notice", "You bandage \a [W.desc] on [M]'s [affecting.name] with a rag, tying it in place."))
					W.bandage()
					qdel(src) // the rag is used up, it'll be all bloody and useless after
					break // we can only do one at a time
			else if(reagents.total_volume)
				if(user.zone_sel.selecting == "mouth" && !(M.wear_mask && M.wear_mask.item_flags & AIRTIGHT))
					user.do_attack_animation(src)
					user.visible_message(
						span("danger","\The [user] smothers [target] with [src]!"),
						span("warning","You smother [target] with [src]!"),
						"You hear some struggling and muffled cries of surprise."
						)

					//it's inhaled, so... maybe CHEM_BLOOD doesn't make a whole lot of sense but it's the best we can do for now
					//^HA HA HA
					reagents.trans_to_mob(target, amount_per_transfer_from_this, CHEM_BREATHE)
					update_name()
				else
					wipe_down(target, user)
			return

	return ..()

/obj/item/weapon/reagent_containers/glass/rag/afterattack(atom/A as obj|turf|area, mob/user as mob, proximity)
	if(!proximity)
		return

	if(istype(A, /obj/structure/reagent_dispensers) || istype(A, /obj/structure/mopbucket) || istype(A, /obj/item/weapon/reagent_containers/glass))
		if(!reagents.get_free_space())
			to_chat(user, "<span class='warning'>\The [src] is already soaked.</span>")
			return

		if(A.reagents && A.reagents.trans_to_obj(src, reagents.maximum_volume))
			playsound(loc, 'sound/effects/slosh.ogg', 25, 1)
			user.visible_message("<span class='notice'>\The [user] soaks [src] using [A].</span>", "<span class='notice'>You soak [src] using [A].</span>")
			update_name()
		return

	if(!on_fire && istype(A) && (src in user))
		if(A.is_open_container() && !(A in user))
			remove_contents(user, A)
		else if(!ismob(A)) //mobs are handled in attack() - this prevents us from wiping down people while smothering them.
			wipe_down(A, user)
		return

/obj/item/weapon/reagent_containers/glass/rag/fire_act(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	if(exposed_temperature >= 50 + T0C)
		ignite()
	if(exposed_temperature >= 900 + T0C)
		new /obj/effect/decal/cleanable/ash(get_turf(src))
		qdel(src)

//rag must have a minimum of 2 units welder fuel and at least 80% of the reagents must be welder fuel.
//maybe generalize flammable reagents someday
/obj/item/weapon/reagent_containers/glass/rag/proc/can_ignite()
	var/fuel = reagents.get_reagent_amount("fuel")
	return (fuel >= 2 && fuel >= reagents.total_volume*0.8)

/obj/item/weapon/reagent_containers/glass/rag/proc/ignite()
	if(on_fire)
		return
	if(!can_ignite())
		return

	//also copied from matches
	if(reagents.get_reagent_amount("phoron")) // the phoron explodes when exposed to fire
		visible_message("<span class='danger'>\The [src] conflagrates violently!</span>")
		var/datum/effect/effect/system/reagents_explosion/e = new()
		e.set_up(round(reagents.get_reagent_amount("phoron") / 2.5, 1), get_turf(src), 0, 0)
		e.start()
		qdel(src)
		return

	START_PROCESSING(SSprocessing, src)
	set_light(2, null, "#E38F46")
	on_fire = 1
	update_name()
	update_icon()

/obj/item/weapon/reagent_containers/glass/rag/proc/extinguish()
	STOP_PROCESSING(SSprocessing, src)
	set_light(0)
	on_fire = 0

	//rags sitting around with 1 second of burn time left is dumb.
	//ensures players always have a few seconds of burn time left when they light their rag
	if(burn_time <= 5)
		visible_message("<span class='warning'>\The [src] falls apart!</span>")
		new /obj/effect/decal/cleanable/ash(get_turf(src))
		qdel(src)
	update_name()
	update_icon()

/obj/item/weapon/reagent_containers/glass/rag/process()
	if(!can_ignite())
		visible_message("<span class='warning'>\The [src] burns out.</span>")
		extinguish()

	//copied from matches
	if(isliving(loc))
		var/mob/living/M = loc
		M.IgniteMob()
	var/turf/location = get_turf(src)
	if(location)
		location.hotspot_expose(700, 5)

	if(burn_time <= 0)
		STOP_PROCESSING(SSprocessing, src)
		new /obj/effect/decal/cleanable/ash(location)
		qdel(src)
		return

	reagents.remove_reagent("fuel", reagents.maximum_volume/25)
	update_name()
	burn_time--
