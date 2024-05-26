// Code adapted from PlayerPawn in gzdoom.pk3 and various functions from Quake 3

class QuakePlayer : PlayerPawn
{
    // Aliases for Player.Forward/SideMove
    Property ForwardMove : forwardMove1, forwardMove2;
    Property SideMove : sideMove1, sideMove2;
    Property UpMove : upMove;

    Property ViewBob : viewBob; // Alias for Player.ViewBob
    Property ViewTilt : viewTilt;
    Property FootstepClass : footstepClass;


    Default
    {
        Speed 320.0 * ups;  // No idea how close Doom & Quake units are, but it feels right
        Player.JumpZ 270.0 * ups;

        MaxStepHeight 18;
        MaxDropOffHeight 18;

        QuakePlayer.UpMove 0.5;
        QuakePlayer.ViewTilt 1.0;
        QuakePlayer.FootstepClass "Footstep";

        Player.DisplayName "QuakePlayer";

        +NoFriction
    }


    const quakeBobCVar = "CG_QuakeBob";
    const runPitchCVar = "CG_RunPitch";
    const runRollCVar = "CG_RunRoll";
    const bobPitchCVar = "CG_BobPitch";
    const bobRollCVar = "CG_BobRoll";
    const bobUpCVar = "CG_BobUp";
    const straferunningCVar = "G_Straferunning";
    const strafejumpingCVar = "G_Strafejumping";
    const waterControlCVar = "SV_WaterControl";
    const flyControlCVar = "SV_FlyControl";
    const assumeCVarDefaultsCVar = "SV_AssumeCVarDefaults";

    const airControlShift = 0.1 - 0.00390625;
    const stillBobShift = 1;
    const moveBobShift = 0.75;

    const stepReturnTics = 0.2 * ticRate;

    const maxYaw = 65536.0;
    const maxPitch = 65536.0;
    const maxForwardMove = 12800;
    const maxSideMove = 10240;
    const maxUpMove = 768;
    const stopFlying = -32768;

    const normalFriction = 0.90625;
    const ups = 1.0 / ticRate;

    const stopSpeed = 100.0 * ups;
    const duckScale = 0.25;
    const swimScale = 0.5;

    const acceleration = 10.0 * ups;

    const groundFriction = 6.0 / ticRate;
    const waterFriction = 1.0 / ticRate;
    const flightFriction = 5.0 / ticRate;

    enum EWaterLevel
    {
        WL_NotInWater   = 0,
        WL_Feet         = 1,
        WL_Waist        = 2,
        WL_Eyes         = 3
    }

    enum EMoveType
    {
        MT_Walk,
        MT_Water,
        MT_Fly,
        MT_Air
    }


    double upMove;
    double viewTilt;
    class<Actor> footstepClass;

    double bobCycle;
    double bobFracSin;
    double lastPitch;
    double lastRoll;

    bool isCrouching;
    bool isRunning;


    override void PlayerThink()
    {
        bool predicting = player.cheats & CF_Predicting;

        CheckFOV();
        if (player.inventoryTics) --player.inventoryTics;
        CheckCheats();

		if (player.playerState == PST_Dead)
		{   // Is there a reason CheckCrouch is before this in gzdoom.pk3?
            Friction();
			DeathThink();
			return;
		}
		if (player.morphTics && !predicting)
		{
			MorphPlayerThink();
		}

        bool wasOnGround = player.onGround;
		player.onGround = (pos.z <= floorZ) || bOnMobj || bMBFBouncer || (player.cheats & CF_NoClip2);

        // Stick player to ground when going down stairs
        if (wasOnGround && !player.onGround && pos.z - GetZAt() < maxDropOffHeight && vel.z <= 0)
        {
            player.viewHeight += (pos.z - GetZAt());
            player.deltaViewHeight -= (pos.z - GetZAt()) / 8;
            SetZ(GetZAt());
            player.onGround = true;
        }

        // I'm not sure how this is done in PlayerPawn
        // Put player back in idle state after moving
        if (!player.cmd.forwardMove && !player.cmd.sideMove && (!player.onGround || !player.vel.Length())) PlayIdle();

        HandleMovement();

        if (!predicting)
        {
            // NOTE: CheckUndoMorph may change PlayerPawn, and invalidate self.player (I think)
            PlayerInfo player = self.player;

            CheckEnvironment();
			CheckUse();
			CheckUndoMorph();

			player.mo.TickPSprites();

			// Other Counters
			if (player.damagecount)	player.damagecount--;
			if (player.bonuscount) player.bonuscount--;

            // Strife-style poison
			if (player.hazardcount)
			{
				player.hazardcount--;
				if (!(level.time % player.hazardinterval) && player.hazardcount > 16 * ticRate)
					player.mo.DamageMobj (NULL, NULL, 5, player.hazardtype);
			}

			player.mo.CheckPoison();
			player.mo.CheckDegeneration();
			player.mo.CheckAirSupply();
        }
    }


    //////////////
    // Movement //
    //////////////

    override void HandleMovement()
    {
        FixPlayerInput();
        CheckCrouch(CheckFrozen());

        CheckPitch();

		if (reactiontime)
		{   // Player is frozen
			reactiontime--;
		}
		else
		{
            CheckYaw();

            switch (GetMoveType())
            {
            case MT_Walk:
                WalkMove();
                break;
            case MT_Fly:
                FlyMove();
                break;
            case MT_Water:
                WaterMove();
                break;
            case MT_Air:
                AirMove();
                break;
            }
		}

        Footsteps();
        CalcHeight();   // View bob
    }


    // Modifies player input in special circumstances
    virtual void FixPlayerInput()
    {
        UserCmd cmd = player.cmd;

        PullIn();

        switch (GetMoveType())
        {
        case MT_Fly:
        case MT_Water:
            if (IsPressed(BT_Jump))
            {
                cmd.upMove = maxUpMove;
            }

            if (IsPressed(BT_Crouch))
            {
                cmd.upMove = -maxUpMove;
            }

            break;
        }
    }


    // Chainsaw/Gauntlets attack auto forward motion
    virtual void PullIn()
    {
        UserCmd cmd = player.cmd;

		if (bJustAttacked)
		{
			cmd.yaw = 0;
			cmd.forwardmove = 0xc800/2;
			cmd.sidemove = 0;
			bJustAttacked = false;
		}
    }


    // Handle player turning
    virtual void CheckYaw()
    {
        UserCmd cmd = player.cmd;

        // [RH] Check for fast turn around
		if (player.cmd.buttons & BT_TURN180 && !(player.oldbuttons & BT_TURN180))
		{
			player.turnticks = TURN180_TICKS;
		}

		// [RH] 180-degree turn overrides all other yaws
		if (player.turnticks)
		{
			player.turnticks--;
			Angle += (180. / TURN180_TICKS);
		}
		else
		{
			Angle += cmd.yaw * (360./65536.);
		}
    }


    override void CheckCrouch(bool totallyFrozen)
    {
        // Not entirely sure what player.crouching is
        isCrouching = CanCrouch() && level.IsCrouchingAllowed() && (IsPressed(BT_Crouch) || player.crouching < 0);

        Super.CheckCrouch(totallyFrozen);
    }


    override void CheckJump()
    {
        if (JustPressed(BT_Jump))
        {
            // Copypasted from CheckJump
            if (player.crouchoffset != 0)
            {
                // Jumping while crouching will force an un-crouch but not jump
                player.crouching = 1;
            }
            else if (level.IsJumpingAllowed() && player.onGround)
            {
                double jumpvelz = JumpZ * 35 / TICRATE;
                double jumpfac = 0;

                // [BC] If the player has the high jump power, double his jump velocity.
                // (actually, pick the best factors from all active items.)
                for (let p = Inv; p != null; p = p.Inv)
                {
                    let pp = PowerHighJump(p);
                    if (pp)
                    {
                        double f = pp.Strength;
                        if (f > jumpfac) jumpfac = f;
                    }
                }
                if (jumpfac > 0) jumpvelz *= jumpfac;

                Vel.Z += jumpvelz;
                bOnMobj = false;
                player.onGround = false;
                if (!(player.cheats & CF_PREDICTING)) A_PlaySound("*jump", CHAN_BODY);
            }
        }
    }


    virtual void WalkMove()
    {
		UserCmd cmd = player.cmd;

        CheckFlight();
        CheckJump();
        if (!player.onGround)
        {
            if (waterLevel) WaterMove();
            else AirMove();

            return;
        }

        Friction();

        if (cmd.forwardMove || cmd.sideMove)
        {
			double fm = cmd.forwardmove;
			double sm = cmd.sidemove;
			[fm, sm] = TweakSpeeds(fm, sm);
            fm /= maxForwardMove;
            sm /= maxSideMove;

            bool canStraferun = CVar.FindCVar(straferunningCVar).GetBool();
            double scale = CmdScale();
            fm *= scale;
            sm *= scale;

            Vector3 forward = (AngleToVector(angle), 0);
            Vector3 right = (AngleToVector(angle - 90), 0);
            Vector3 wishVel = fm * forward + sm * right;

            Vector3 wishDir = wishVel.Unit();
            double wishSpeed = wishVel.Length();

            // Crouch walk is slower
            if (isCrouching)
            {
                wishSpeed = Min(wishSpeed, speed * duckScale);
            }

            // So is wading
            if (waterlevel)
            {
                double waterScale = double(waterLevel) / 3;
                waterScale = 1 - (1 - swimScale) * waterScale;
                wishSpeed = Min(wishSpeed, speed * waterScale);
            }

            double accel = GetMoveFactor() * acceleration;
            Accelerate(wishDir, wishSpeed, accel);
            BobAccelerate(wishDir, wishSpeed, accel);

            // Running animation
			if (!(player.cheats & CF_PREDICTING) && (fm != 0 || sm != 0)) PlayRunning();

            // Return to 1st person (from security camera?)
			if (player.cheats & CF_RevertPlease)
			{
				player.cheats &= ~CF_RevertPlease;
				player.camera = player.mo;
			}
        }
    }


    virtual void FlyMove()
    {
		UserCmd cmd = player.cmd;

        if (cmd.upMove == stopFlying)
        {
            bNoGravity = false;
            cmd.upMove = 0; // To avoid AirMove calling FlyMove again
            AirMove();
            return;
        }

        Friction();

        if (cmd.forwardMove || cmd.sideMove || cmd.upMove)
        {
			double fm = cmd.forwardmove;
			double sm = cmd.sidemove;
            double um = cmd.upMove;
            [fm, sm, um] = TweakSpeeds3(fm, sm, um);
            fm /= maxForwardMove;
            sm /= maxSideMove;
            um /= maxUpMove;

            bool canStraferun = CVar.FindCVar(straferunningCVar).GetBool();
            double scale = CmdScale();
            fm *= scale;
            sm *= scale;
            um *= scale;

            Vector3 forward = (Cos(pitch) * Cos(angle), Cos(pitch) * Sin(angle), -Sin(pitch));
            Vector3 right = (AngleToVector(angle - 90), 0);
            Vector3 wishVel = fm * forward + sm * right;
            wishVel.z += um;

            Vector3 wishDir = wishVel.Unit();
            double wishSpeed = wishVel.Length();

            double accel = CVar.GetCVar(flyControlCVar).GetFloat();
            accel *= GetMoveFactor() * acceleration;
            Accelerate(wishDir, wishSpeed, accel);
            BobAccelerate(wishDir, wishSpeed, accel);

            // Running animation
			if (!(player.cheats & CF_PREDICTING) && (fm != 0 || sm != 0)) PlayRunning();

            // Return to 1st person (from security camera?)
			if (player.cheats & CF_RevertPlease)
			{
				player.cheats &= ~CF_RevertPlease;
				player.camera = player.mo;
			}
        }
    }


    virtual void WaterMove()
    {
		UserCmd cmd = player.cmd;

        Friction();

        if (cmd.forwardMove || cmd.sideMove || cmd.upMove)
        {
			double fm = cmd.forwardmove;
			double sm = cmd.sidemove;
            double um = cmd.upMove;
            [fm, sm, um] = TweakSpeeds3(fm, sm, um);
            fm /= maxForwardMove;
            sm /= maxSideMove;
            um /= maxUpMove;

            bool canStraferun = CVar.FindCVar(straferunningCVar).GetBool();
            double scale = CmdScale();
            fm *= scale;
            sm *= scale;
            um *= scale;

            Vector3 forward = (Cos(pitch) * Cos(angle), Cos(pitch) * Sin(angle), -Sin(pitch));
            Vector3 right = (AngleToVector(angle - 90), 0);
            Vector3 wishVel = fm * forward + sm * right;
            wishVel.z += um;

            if (waterLevel == WL_Feet && wishVel.z > 0) wishVel.z = 0;   // Swim on surface
            if (wishVel.Length() == 0) return;

            Vector3 wishDir = wishVel.Unit();
            double wishSpeed = wishVel.Length();

            wishSpeed = Min(wishSpeed, speed * swimScale);

            double accel = CVar.GetCVar(waterControlCVar).GetFloat();
            accel *= GetMoveFactor() * acceleration;
            Accelerate(wishDir, wishSpeed, accel);
            BobAccelerate(wishDir, wishSpeed, accel);

            // Running animation
			if (!(player.cheats & CF_PREDICTING) && (fm != 0 || sm != 0)) PlayRunning();

            // Return to 1st person (from security camera?)
			if (player.cheats & CF_RevertPlease)
			{
				player.cheats &= ~CF_RevertPlease;
				player.camera = player.mo;
			}
        }
    }


    virtual void AirMove()
    {
		UserCmd cmd = player.cmd;

        CheckFlight();
        CheckJump();    // In case CheckJump is overridden to allow double jump, mantling, etc.
        Friction();

        if (cmd.forwardMove || cmd.sideMove)
        {
			double fm = cmd.forwardmove;
			double sm = cmd.sidemove;
			[fm, sm] = TweakSpeeds(fm, sm);
            fm /= maxForwardMove;
            sm /= maxSideMove;

            double scale = CmdScale();
            fm *= scale;
            sm *= scale;

            Vector3 forward = (AngleToVector(angle), 0);
            Vector3 right = (AngleToVector(angle - 90), 0);
            Vector3 wishVel = fm * forward + sm * right;

            Vector3 wishDir = wishVel.Unit();
            double wishSpeed = wishVel.Length();

            bool shift = CVar.GetCVar(assumeCVarDefaultsCVar).getBool();
            double accel = level.airControl + (shift ? airControlShift : 0);
            accel *= GetMoveFactor() * acceleration;
            Accelerate(wishDir, wishSpeed, accel);
            BobAccelerate(wishDir, wishSpeed, accel);

            // Running animation
			if (!(player.cheats & CF_PREDICTING) && (fm != 0 || sm != 0)) PlayRunning();

            // Return to 1st person (from security camera?)
			if (player.cheats & CF_RevertPlease)
			{
				player.cheats &= ~CF_RevertPlease;
				player.camera = player.mo;
			}
        }
    }


    virtual void CheckFlight()
    {
        UserCmd cmd = player.cmd;

        if (cmd.upMove)
        {
            if (bFly || (player.cheats & CF_NOCLIP2))
            {
                bFly = true;
                bNoGravity = true;

                if ((Vel.Z <= -39) && !(player.cheats & CF_PREDICTING))
                {   // Stop falling scream
                    A_StopSound(CHAN_VOICE);
                }

                FlyMove();
                return;
            }
            else if (cmd.upMove > 0 && !(player.cheats & CF_PREDICTING))
			{
				let fly = FindInventory("ArtiFly");
				if (fly)
                {
                    UseInventory(fly);

                    FlyMove();
                    return;
                }
			}
        }
    }


    virtual double, double, double TweakSpeeds3(double forward, double side, double up)
    {
        [forward, side] = TweakSpeeds(forward, side);

        up *= upMove;

        return forward, side, up;
    }


    virtual double CmdScale()
    {
        bool canStraferun = CVar.FindCVar(straferunningCVar).GetBool();
        if (canStraferun) return speed;

		UserCmd cmd = player.cmd;
        double fm = double(cmd.forwardMove) / maxForwardMove;
        double sm = double(cmd.sideMove) / maxSideMove;
        double um = double(cmd.upMove) / maxUpMove;

        double maxCmd = Max(Abs(fm), Abs(sm), Abs(um));
        double total = (fm, sm, um).Length();

        double scale = total ? speed * maxCmd / total : 0;

        isRunning = scale > speed / 2;

        return scale;
    }


    virtual void Friction()
    {
        double spd = vel.Length();
        if (spd < ups)
        {
            vel.xy = (0, 0);
            player.vel = (0, 0);
            return; // Prevents div by 0
        }

        double drop = 0;

        if (waterLevel <= WL_Feet && player.onGround)
        {
            double control = Max(spd, stopSpeed);
            drop += control * groundFriction;
            drop *= GetMoveFactor();
        }

        if (waterLevel)
        {
            drop += spd * waterFriction * waterLevel;
        }

        if (bNoGravity)
        {
            drop += spd * flightFriction;
        }

        double newSpeed = Max(spd - drop, 0) / spd;
        vel *= newSpeed;
        player.vel *= newSpeed;
    }


    virtual void Accelerate(Vector3 wishDir, double wishSpeed, double accel)
    {
        if (CVar.FindCVar(strafejumpingCVar).GetBool())
        {
            double currentSpeed = vel dot wishDir;

            double addSpeed = wishSpeed - currentSpeed;
            if (addSpeed <= 0) return;

            double accelSpeed = Min(accel * wishSpeed, addSpeed);

            vel += accelSpeed * wishDir;
        }
        else
        {   // Disabled code in Quake 3
            Vector3 pushDir = wishSpeed * wishDir - vel;
            double pushLen = pushDir.Length();
            if (pushLen == 0) return;
            pushDir = pushDir.Unit();

            double canPush = Min(accel * wishSpeed, PushLen);

            vel += canPush * pushDir;
        }
    }


    virtual void BobAccelerate(Vector3 wishDir, double wishSpeed, double accel)
    {
        double currentSpeed = player.vel dot wishDir.xy;

        double addSpeed = wishSpeed - currentSpeed;
        if (addSpeed <= 0) return;

        double accelSpeed = Clamp(accel * wishSpeed, 0, addSpeed);

        player.vel += accelSpeed * wishDir.xy;
    }


    // Returns whether player is walking, swimming, etc.
    virtual int GetMoveType()
    {
        if (bNoGravity)             return MT_Fly;
        if (waterLevel > WL_Feet)   return MT_Water;    // In Quake, you can only swim when waist deep
        if (waterLevel == WL_Feet                       // In Doom, you can practically walk on water
            && !player.onGround)    return MT_Water;    // This is a compromise, so you can jump in shallow water
        if (player.onGround)        return MT_Walk;
        else                        return MT_Air;
    }


    // Slow player down if ground is slippery/sticky
    virtual double GetMoveFactor()
    {
        double friction = GetFriction();

        if (friction > normalFriction) return 1 - ((friction - normalFriction) / (1 - normalFriction));
        else if (friction < normalFriction) return 1 - ((normalFriction - friction) / normalFriction);
        else return 1;
    }


    /////////////////////////
    // View and weapon bob //
    /////////////////////////

    // Adapted from cg_view.c: CG_OffsetFirstPersonView and player.txt: CalcHeight
    override void CalcHeight()
    {
        if (!CVar.GetCVar(QuakeBobCVar, player).GetBool())
        {
            Super.CalcHeight();
            return;
        }

        double newPitch = 0;
        double newRoll = 0;

        // Weapon kick should be handled by weapons themselves

        // Velocity angles
        // Yes, they depend on actual vel, not player-intended vel
        Vector3 forward = (Cos(pitch) * Cos(angle), Cos(pitch) * Sin(angle), -Sin(pitch));
        Vector3 right = (AngleToVector(angle - 90), 0);

        double runPitch = CVar.GetCVar(runPitchCVar, player).GetFloat();
        double delta = (vel dot forward) * ticRate * runPitch * viewTilt;
        newPitch += delta;

        double runRoll = CVar.GetCVar(runRollCVar, player).GetFloat();
        delta = (vel dot right) * ticRate * runRoll * viewTilt;
        newRoll += delta;

        // Bob angles
        double spd = Max(player.bob, 200);   // Make sure bob is obvious at low speeds

        double bobPitch = CVar.GetCVar(bobPitchCVar, player).GetFloat();
        delta = bobFracSin * bobPitch * spd * viewBob;
        if (isCrouching) delta *= 3;
        newPitch += delta;

        double bobRoll = CVar.GetCVar(bobRollCVar, player).GetFloat();
        delta = bobFracSin * bobRoll * spd * viewBob;
        if (isCrouching) delta *= 3;
        if (bobCycle >= 128) delta *= -1;   // Swap direction for left foot
        newRoll += delta;

        A_SetPitch(pitch - lastPitch + newPitch, SPF_Interpolate);
        A_SetRoll(roll - lastRoll + newRoll, SPF_Interpolate);

        lastPitch = newPitch;
        lastRoll = newRoll;

        // Bob height
        double bobUp = CVar.GetCVar(bobUpCVar, player).GetFloat();
        double bob = Min(bobFracSin * player.bob * viewBob * bobUp, 6);

		if (player.morphTics)
		{
			bob = 0;
		}

		double defaultviewheight = ViewHeight + player.crouchviewdelta;

		if (player.cheats & CF_NOVELOCITY)
		{
			player.viewz = pos.Z + defaultviewheight;

			if (player.viewz > ceilingz-4)
				player.viewz = ceilingz-4;

			return;
		}

        // Step offset
		// move viewheight
		if (player.playerstate == PST_LIVE)
        {
            player.viewHeight += player.deltaViewHeight * 8 / stepReturnTics;

            if (player.deltaViewHeight < 0 && player.ViewHeight < defaultViewHeight
                || player.deltaViewHeight > 0 && player.ViewHeight > defaultViewHeight)
            {
                player.viewHeight = defaultViewHeight;
                player.deltaViewHeight = 0;
            }
        }

        // [SP] Allow DECORATE changes to view bobbing speed.
		player.viewz = pos.Z + player.viewheight + (bob * clamp(ViewBob, 0. , 1.5));

		if (Floorclip && player.playerstate != PST_DEAD
			&& pos.Z <= floorz)
		{
			player.viewz -= Floorclip;
		}
		if (player.viewz > ceilingz - 4)
		{
			player.viewz = ceilingz - 4;
		}
		if (player.viewz < floorz + 4)
		{
			player.viewz = floorz + 4;
		}
    }


    // Adapted from cg_weapons.c: CG_CalculateWeaponPosition
    override Vector2 BobWeapon(double ticFrac)
    {
        if (!CVar.GetCVar(QuakeBobCVar, player).GetBool()) return Super.BobWeapon(ticFrac);

        let weapon = player.readyWeapon;
		if (weapon == null || weapon.bDontBob) return (0, 0);

        Vector2 offset = (0, 0);

        // From bobbing
        int xSign = bobCycle >= 128 ? -1 : 1;   // Swap direction for left foot
        Vector2 range = (weapon.bobRangeX * viewBob, weapon.bobRangeY * viewBob);

        // Have to simulate yaw/pitch w/ x/y offset
        // I don't think PSPrites have roll
        offset += (xSign * player.bob * bobFracSin * 0.02 * range.x, player.bob * bobFracSin * 0.01 * range.y);

        // Idle drift
        double spd = player.vel.Length() * ticRate + 40;
        bool shift = CVar.GetCVar(assumeCVarDefaultsCVar).getBool();
        spd *= player.GetStillBob() + (shift ? stillBobShift : 0);
        double fracSin = Sin(double(level.time) / ticRate * (360 / 6.28)) + 1;  // +1 so weapon never goes up
        offset += (-spd * fracSin * 0.02, spd * fracSin * 0.02);

        return offset;
    }


    // Adapted from bg_pmove.c: PM_Footsteps
    virtual void Footsteps()
    {
        UserCmd cmd = player.cmd;

        // player.bob is 35x bigger than in Doom; not sure if that matters for anything
        bool shift = CVar.GetCVar(assumeCVarDefaultsCVar).getBool();
        player.bob = player.vel.Length() * ticRate * (player.GetMoveBob() + (shift ? moveBobShift : 0));

        // airborne leaves position in cycle intact, but doesn't advance
        if (!player.onGround) return;

        if (!cmd.forwardMove && !cmd.sideMove)
        {
            if (vel.xy.Length() < 5 * ups) bobCycle = 0;
            return;
        }

        double bobMove;
        if (isCrouching)    bobMove = 500.0 / ticRate;
        else if (isRunning) bobMove = 400.0 / ticRate;
        else                bobMove = 300.0 / ticRate;

        double old = bobCycle;
        bobCycle = (bobCycle + bobMove) % 256;
        bobFracSin = Abs(Sin((bobCycle % 128) / 127.0 * 180));

        // Spawn footstep every half-cycle
        if (bobCycle > 128 && old <= 128 || old > bobCycle)
        {
            Actor step = Spawn(footstepClass, pos);
            step.master = self;
        }
    }


    bool IsPressed(int bt)
    {
        return player.cmd.buttons & bt;
    }

    bool JustPressed(int bt)
    {
        return (player.cmd.buttons & bt) && !(player.oldButtons & bt);
    }
}
