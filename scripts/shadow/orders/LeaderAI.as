import ship_groups;
import orders;
import resources;

//Factor of new design cost as minimum for retrofit
const double RETROFIT_MIN_PCT = 0.3;
const string TAG_SUPPORT("Support");

class LeaderAI : Component_LeaderAI {
	OrderDesc[] orders;
	Object@[] supports;
	GroupData@[] groupData;

	uint supplyCapacity = 0;
	uint supplyUsed = 0;
	double ghostHP = 0.0;
	double ghostDPS = 0.0;
	double fleetHP = 0.0;
	double fleetDPS = 0.0;
	double fleetMaxHP = 0.0;
	double fleetMaxDPS = 0.0;
	double bonusDPS = 0.0;
	float fleetEffectiveness = 1.f;
	float permanentEffectiveness = 0.f;
	bool autoFill = false;
	bool autoBuy = false;

	AutoMode autoMode = AM_AreaBound;
	EngagementBehaviour engageBehave = EB_CloseIn;
	EngagementRange engageType = ER_SupportMin;

	FleetPlaneNode@ node;

	float getFleetEffectiveness() const {
		return fleetEffectiveness * getBaseFleetEffectiveness();
	}

	float getBaseFleetEffectiveness() const {
		if(permanentEffectiveness < 0)
			return pow(0.5, -2.0 * double(permanentEffectiveness));
		return 1.0 + permanentEffectiveness;
	}

	void setFleetEffectiveness(float value) {
		fleetEffectiveness = value;
	}

	uint getAutoMode() {
		return uint(autoMode);
	}

	uint getEngageBehave() {
		return uint(engageBehave);
	}

	uint getEngageType() {
		return uint(engageType);
	}

	void leaderInit(Object& obj) {
		if(obj.isShip) {
			double formationRad = getFormationRadius(obj);
			@node = FleetPlaneNode();
			node.establish(obj, formationRad);
		}
		leaderChangeOwner(obj, null, obj.owner);
	}

	void leaderDestroy(Object& obj) {
		if(obj.owner !is null && obj.owner.valid)
			obj.owner.unregisterFleet(obj);
		if(node !is null) {
			cast<Node>(node).markForDeletion();
			@node = null;
		}
	}

	void leaderTick(Object& obj, double time) {
		//Set plane visibility
		if(node !is null) {
			node.visible = obj.isVisibleTo(playerEmpire);
			if(obj.region !is null)
				node.hintParentObject(obj.region);
		}
	}

	void leaderChangeOwner(Object& obj, Empire@ oldOwner, Empire@ newOwner) {
		if(oldOwner !is null && oldOwner.valid)
			oldOwner.unregisterFleet(obj);
		if(newOwner !is null && newOwner.valid)
			newOwner.registerFleet(obj);
	}

	int getRetrofitCost(const Object& obj) const {
		int cost = 0;
		bool have = false;
		const Ship@ ship = cast<const Ship>(obj);
		if(ship !is null) {
			const Design@ from = ship.blueprint.design;
			const Design@ to = from.newest();
			if(from !is to && from.hull.hasTag(TAG_SUPPORT) == to.hull.hasTag(TAG_SUPPORT)) {
				int fromCost = getBuildCost(from);
				int toCost = getBuildCost(to);
				cost += max(toCost - fromCost, int(ceil(toCost * RETROFIT_MIN_PCT)));
				have = true;
			}
		}

		for(uint i = 0, cnt = groupData.length; i < cnt; ++i) {
			GroupData@ dat = groupData[i];
			const Design@ from = dat.dsg;
			const Design@ to = from.newest();
			if(from !is to && from.hull.hasTag(TAG_SUPPORT) == to.hull.hasTag(TAG_SUPPORT)) {
				int fromCost = getBuildCost(from);
				int toCost = getBuildCost(to);
				cost += max(toCost - fromCost, int(ceil(toCost * RETROFIT_MIN_PCT))) * dat.amount;
				have = true;
			}
		}

		if(!have)
			return -1;
		else
			return cost;
	}

	double getRetrofitLabor(const Object& obj) const {
		double cost = 0;
		bool have = false;
		const Ship@ ship = cast<const Ship>(obj);
		if(ship !is null) {
			const Design@ from = ship.blueprint.design;
			const Design@ to = from.newest();
			if(from !is to && from.hull.hasTag(TAG_SUPPORT) == to.hull.hasTag(TAG_SUPPORT)) {
				double fromCost = getLaborCost(from);
				double toCost = getLaborCost(to);
				cost += max(toCost - fromCost, toCost * RETROFIT_MIN_PCT);
				have = true;
			}
		}

		for(uint i = 0, cnt = groupData.length; i < cnt; ++i) {
			GroupData@ dat = groupData[i];
			const Design@ from = dat.dsg;
			const Design@ to = from.newest();
			if(from !is to && from.hull.hasTag(TAG_SUPPORT) == to.hull.hasTag(TAG_SUPPORT)) {
				double fromCost = getLaborCost(from);
				double toCost = getLaborCost(to);
				cost += max(toCost - fromCost, toCost * RETROFIT_MIN_PCT) * dat.amount;
				have = true;
			}
		}

		if(!have)
			return -1;
		else
			return cost;
	}

	double get_GhostHP() const {
		return ghostHP;
	}

	double get_GhostDPS() const {
		return ghostDPS;
	}
	
	bool get_hasOrders() {
		return orders.length != 0;
	}

	bool hasOrder(uint type, bool checkQueued = false) {
		if(orders.length == 0)
			return false;
		if(!checkQueued)
			return orders[0].type == type;
		for(int i = orders.length - 1; i >= 0; --i) {
			if(orders[i].type == type)
				return true;
		}
		return false;
	}

	uint get_orderCount() {
		return orders.length;
	}

	string get_orderName(uint num) {
		return "(null)"; //TODO
	}

	uint get_orderType(uint num) {
		if(num >= orders.length)
			return 0;
		return orders[num].type;
	}

	bool get_orderHasMovement(uint num) {
		if(num >= orders.length)
			return false;
		return orders[num].hasMovement;
	}

	vec3d get_orderMoveDestination(uint num) {
		if(num >= orders.length)
			return vec3d();
		return orders[num].moveDestination;
	}

	vec3d get_finalMoveDestination(const Object& obj) {
		for(int i = orders.length - 1; i >= 0; --i) {
			if(orders[i].hasMovement)
				return orders[i].moveDestination;
		}
		return obj.position;
	}

	void getSupportGroups() const {
		for(uint i = 0, cnt = groupData.length; i < cnt; ++i)
			yield(groupData[i]);
	}

	double getFormationRadius(Object& obj) {
		Planet@ pl = cast<Planet>(obj);
		if(pl !is null)
			return pl.OrbitSize;
		return obj.radius * 10.0 + 20.0;
	}

	uint get_supportCount() {
		return supports.length;
	}

	Object@ get_supportShip(uint index) {
		if(index >= supports.length)
			return null;
		auto@ supp = supports[index];
		if(!supp.valid || !supp.initialized)
			return null;
		return supp;
	}

	uint get_SupplyUsed() const {
		return supplyUsed;
	}

	uint get_SupplyCapacity() const {
		return supplyCapacity;
	}

	uint get_SupplyAvailable() const {
		return supplyCapacity - supplyUsed;
	}
	
	void updateFleetStrength(Object& obj) {
		double hp = 0.0, dps = 0.0, maxHP = 0.0, maxDPS = 0.0;
		
		if(obj.isShip && obj.valid) {
			Ship@ ship = cast<Ship>(obj);
			hp = ship.blueprint.currentHP;
			dps = ship.DPS * ship.blueprint.shipEffectiveness;
			
			maxHP = ship.blueprint.design.totalHP;
			maxDPS = ship.MaxDPS;
		}
		if(obj.isOrbital && obj.valid) {
			Orbital@ orb = cast<Orbital>(obj);
			hp = orb.health + orb.armor;
			maxHP = orb.maxHealth + orb.maxArmor;
			maxDPS = orb.dps;
			dps = maxDPS * orb.efficiency;
		}

		for(uint i = 0, cnt = supports.length; i < cnt; ++i) {
			Ship@ ship = cast<Ship>(supports[i]);
			if(ship !is null && ship.valid && ship.initialized) {
				auto@ bp = ship.blueprint;
				hp += bp.currentHP;
				dps += ship.DPS * bp.shipEffectiveness;
				maxHP += bp.design.totalHP;
				maxDPS += ship.MaxDPS;
			}
		}
		
		fleetHP = hp;
		fleetDPS = dps;
		fleetMaxHP = maxHP;
		fleetMaxDPS = maxDPS;
	}

	void transferSupports(Object& obj, const Design@ ofDesign, uint amount, Object@ transferTo) {
		if(!transferTo.hasLeaderAI || ofDesign is null || amount == 0)
			return;

		int ind = getGroupDataIndex(ofDesign, false);
		if(ind == -1)
			return;

		//Don't try to transfer over our supply cap
		amount = min(amount, transferTo.SupplyAvailable / uint(ofDesign.size));
		if(amount == 0)
			return;

		ind = getGroupDataIndex(ofDesign, false);
		if(ind == -1)
			return;
		GroupData@ dat = groupData[ind];

		//Transfer real ships over first
		uint take = min(dat.amount, amount);
		if(take != 0) {
			amount -= take;
			dat.amount -= take;
			supplyUsed -= take * ofDesign.size;
			transferTo.addFakeSupports(ofDesign, take);
		}

		if(dat.totalSize <= 0)
			groupData.removeAt(ind);

		//Transfer ordered
		if(amount == 0)
			return;

		take = min(dat.ordered, amount);
		if(take != 0) {
			amount -= take;
			dat.ordered -= take;
			supplyUsed -= take * ofDesign.size;
			transferTo.addSupportOrdered(ofDesign, take);
		}

		if(dat.totalSize <= 0)
			groupData.removeAt(ind);

		//Transfer ghosts
		if(amount == 0)
			return;

		take = min(dat.ghost, amount);
		if(take != 0) {
			dat.ghost -= take;
			amount -= take;
			supplyUsed -= take * ofDesign.size;
			transferTo.addSupportGhosts(ofDesign, take);
		}

		if(dat.totalSize <= 0)
			groupData.removeAt(ind);
	}

	void orderSupports(Object& obj, const Design@ ofDesign, uint amount) {
		if(!obj.owner.canPay(getBuildCost(ofDesign, amount)))
			return;

		int index = getGroupDataIndex(ofDesign, true);
		groupData[index].ordered += amount;
	}

	void addSupportGhosts(Object& obj, const Design@ ofDesign, uint amount) {
		int ind = getGroupDataIndex(ofDesign, true);

		GroupData@ dat = groupData[ind];
		dat.ghost += amount;
		supplyUsed += amount * ofDesign.size;
	}

	void addSupportOrdered(Object& obj, const Design@ ofDesign, uint amount) {
		int ind = getGroupDataIndex(ofDesign, true);
		GroupData@ dat = groupData[ind];
		dat.ordered += amount;
		supplyUsed += amount * ofDesign.size;
	}

	void addFakeSupports(Object& obj, const Design@ ofDesign, uint amount) {
		int ind = getGroupDataIndex(ofDesign, true);
		GroupData@ dat = groupData[ind];
		dat.amount += amount;
		supplyUsed += amount * ofDesign.size;
	}
	
	double getFleetHP() const {
		return fleetHP;
	}
	
	double getFleetDPS() const {
		return fleetDPS + bonusDPS;
	}

	double getFleetStrength(const Object& obj) const {
		return fleetHP * (fleetDPS + bonusDPS);
	}

	double getFleetMaxStrength(const Object& obj) const {
		return fleetMaxHP * (fleetMaxDPS + bonusDPS) * getBaseFleetEffectiveness();
	}

	int getGroupDataIndex(const Design@ dsg, bool create = false) {
		@dsg = dsg.mostUpdated();
		for(uint i = 0, cnt = groupData.length; i < cnt; ++i) {
			GroupData@ dat = groupData[i];
			const Design@ oldDesign = dat.dsg;
			const Design@ newDesign = dat.dsg.mostUpdated();
			if(newDesign is dsg.mostUpdated()) {
				if(oldDesign !is newDesign)
					@dat.dsg = newDesign;
				return i;
			}
		}
		if(create) {
			GroupData dat;
			@dat.dsg = dsg.mostUpdated();

			groupData.insertLast(dat);
			return groupData.length - 1;
		}
		return -1;
	}

	uint getGhostCount(const Design@ dsg) const {
		int ind = getGroupDataIndex(dsg);
		if(ind == -1)
			return 0;
		return groupData[ind].ghost;
	}

	void readOrders(Message& msg) {
		msg.readAlign();
		uint cnt = msg.read_uint();
		orders.length = cnt;
		for(uint i = 0; i < cnt; ++i)
			orders[i].read(msg);

		autoMode = AutoMode(msg.readSmall());
		engageType = EngagementRange(msg.readSmall());
		engageBehave = EngagementBehaviour(msg.readSmall());
		msg >> autoFill >> autoBuy;
	}

	bool get_autoBuySupports() {
		return autoBuy;
	}

	bool get_autoFillSupports() {
		return autoFill;
	}

	void set_autoBuySupports(bool value) {
		autoBuy = value;
	}

	void set_autoFillSupports(bool value) {
		autoFill = value;
	}

	void readGroup(Message& msg) {
		bool hadSupports = supports.length > 0;
		uint cnt = 0;
		msg >> cnt;
		supports.length = cnt;
		for(uint i = 0; i < cnt; ++i)
			msg >> supports[i];

		msg >> cnt;
		groupData.length = cnt;
		double gHP = 0, gDPS = 0;
		for(uint i = 0; i < cnt; ++i) {
			GroupData@ dat = groupData[i];
			if(dat is null) {
				@dat = GroupData();
				@groupData[i] = dat;
			}
			msg >> dat;

			if(dat.dsg !is null) {
				gHP += double(dat.ghost) * dat.dsg.totalHP;
				gDPS += double(dat.ghost) * dat.dsg.total(SV_DPS);
			}
		}

		ghostHP = gHP;
		ghostDPS = gDPS;

		bool hadSupply = supplyCapacity > 0;
		msg >> supplyCapacity;
		msg >> supplyUsed;
		msg >> fleetEffectiveness;
		msg >> permanentEffectiveness;
		msg >> bonusDPS;
		
		if(node !is null) {
			if(hadSupply != (supplyCapacity > 0))
				node.hasSupply = supplyCapacity > 0;
			if(hadSupports != (supports.length > 0))
				node.hasFleet = supports.length > 0;
		}
	}

	void readLeaderAI(Object& obj, Message& msg) {
		readGroup(msg);
		readOrders(msg);
	}

	void readLeaderAIDelta(Message& msg) {
		if(msg.readBit())
			readGroup(msg);
		if(msg.readBit())
			readOrders(msg);
	}
};
