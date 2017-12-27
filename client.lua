local sfw = getScreenFromWorldPosition;
local rockets = {};
local camEnabled = false;

function Rocket(x, y, z, force, target, lifespan, creator)
	local self = {};
	table.insert(rockets, self);
	self.index = nil;
	self.pos = Vector3(x, y, z);
	self.vel = force or Vector3();
	self.target = target;
	self.creator = creator;
	self.isDead = false;
	local life = getTickCount();
	self.lifespan = lifespan or 15000;
	self.groundCheckDist = 0.05;
	local targetHit = false;
	self.marker = Marker(self.pos, "corona", 0.5, 255,0,0);
	self.light = Light(0, self.pos);

	function self.update(dt)
		self.vel.z = self.vel.z - 0.005

		if (type(self.target) == "userdata") then
			self.vel = self.vel * 0.99;
		end
		
		self.pos = self.pos + self.vel --* dt/33;

		local gp = getGroundPosition(self.pos.x, self.pos.y, self.pos.z) + self.groundCheckDist;
		if (self.pos.z < gp) then
			self.pos.z = gp;
		end
	end

	function self.show()
		local vel = (-self.vel);
		dxDrawLine3D(self.pos, self.pos+self.vel, tocolor(255,0,0), 4);
		Effect.addBulletImpact(self.pos, vel*5, 6, 0, .5);
		Effect.addSparks(self.pos, vel, 30, 10, 0,0,0, true, .05, .2);

		self.marker.position = self.pos;
		self.light.position = self.pos;
	end

	function self.expired(ls)
		return getTickCount() > life + (ls or self.lifespan);
	end

	function self.destroy()
		for k,v in pairs(self) do
			if (isElement(v) and v ~= self.target) then
				v:destroy();
			end
		end
		table.remove(rockets, self.index);
	end

	function self.explode()
		createExplosion(self.pos, 12);
		self.destroy();
	end

	local deflected = getTickCount();
	self.deflectCount = 0;
	self.maxDeflections = 1000;
	self.deflectMinDelay = 200;

	function self.deflect()
		local col = self.colliding();
		if (col) then
			if (getTickCount() < deflected + self.deflectMinDelay) then
				self.deflectCount = self.deflectCount + 1;
				if (self.deflectCount == self.maxDeflections) then
					self.isDead = true;
				end
			else
				if (self.deflectCount > 0) then
					self.deflectCount = self.deflectCount - 1;
				end
			end
			deflected = getTickCount();

			self.vel.x = self.vel.x * 0.95;
			self.vel.y = self.vel.y * 0.95;


			if (self.deflectCount > 0) then
				self.vel.z = self.vel.z * 0.3;
			else
				self.vel.z = self.vel.z * 0.72;
			end

			self.vel:deflect(col.normal);
		end
	end

	function self.colliding(target)
		local targetPos = self.pos + self.vel * 1.5;
		local hit, x, y, z, elem, mx, my, mz = processLineOfSight(self.pos, targetPos, _, false, _, _, _, _, _, _, self.obj);
		
		if (elem and elem == self.target) then
			fxAddBlood( x, y, z, self.vel, 3, 1 );
			targetHit = true;
		end

		return hit and {
			pos = Vector3(x, y, z),
			elem = elem,
			normal = Vector3(mx, my, mz)
		}
	end

	function self.follow()
		local target = isElement(self.target) and self.target.position or false;
		if (type(target) == "userdata") then
			local force = (target - self.pos):getNormalized();
			self.vel = self.vel + force * 0.02;
			local d = (self.pos-target).length;
			if (targetHit) then
				self.isDead = true;
			end
		end
	end

	local trail = {};
	local trailUpdated = getTickCount();
	self.trailColor = {math.random(255), math.random(255), math.random(255)};
	self.trailUpdateRate = 10;
	self.trailLength = 20;
	self.trailThickness = 4;

	function self.trail()
		if (#trail == self.trailLength) then
			table.remove(trail, 1);
		end

		if (getTickCount() > self.trailUpdateRate + trailUpdated) then
			trailUpdated = getTickCount();
			table.insert(trail, Vector3(self.pos.x, self.pos.y, self.pos.z));
		end

		for i=#trail, 1, -1  do
			local color = tocolor(self.trailColor[1], self.trailColor[2], self.trailColor[3], i*9);
			if (trail[i+1]) then
				dxDrawLine3D(trail[i], trail[i+1], color, self.trailThickness);
			end
		end
	end

	return self;
end

addEventHandler("onClientPreRender", root, function(dt)
	for i=#rockets, 1, -1 do
		local m = rockets[i];
		m.index = i;
		if (m.expired() or m.isDead) then
			if (i == #rockets and camEnabled) then
				resetCamera();
			end
			m.explode();
		else
			if (type(m.target) == "userdata") then
				m.follow();
			end
			m.deflect();
			m.update(dt);
			m.show();
			m.trail();
		end
	end

	if (camEnabled) then
		local m = rockets[#rockets];
		if (m) then
			Camera.setMatrix(m.pos, m.pos+m.vel, 0, 120);
		end
	end
end);

addCommandHandler("cam", function()
	camEnabled = not camEnabled;
	if (not camEnabled) then
		resetCamera()
	else
		localPlayer.frozen = true;
	end
end);

function resetCamera()
	localPlayer.frozen = false;
	setCameraTarget(localPlayer);
end

function Vector3:deflect(normal)
	local dir = normal * self:dot(normal) * 2;
	self.x = self.x - dir.x;
	self.y = self.y - dir.y;
	self.z = self.z - dir.z;
	return self;
end
