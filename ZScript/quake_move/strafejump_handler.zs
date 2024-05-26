class StrafejumpHandler : EventHandler
{
    const helpCVar = "HelpMeMommy";
    const strafejumpCVar = "G_Strafejumping";
    const onMsg = "\c*Crash: Fine, %s, but you have to learn to ride without training wheels someday.";
    const offMsg = "\c*Crash: Aww, you're finally growing up.";
    const cantMsg = "\c*Crash: Uhh, you realize strafejumping is disabled, right?";
    const msgDelay = Thinker.ticRate;
    const chatSound = "misc/chat";
    const defaultTurnTics = 8;
    const jumpCmd = "+jump";
    const forwardCmd = "+forward";
    const maxSideMove = 10240;
    const yawPerDegree = 65536.0/360;
    const ticRate = 35;
    const normalFriction = 0.7656;
    const acceleration = 10.0 / ticRate / normalFriction;


    ui bool initialized;
    ui bool helping;
    ui int msgTics;
    ui String msg;
    ui bool isJumpDown;
    ui bool isForwardDown;


    override void UITick()
    {
        if (!initialized) Init();

        CheckCVar();
        PrintMsg();

        CheckStrafejump();
    }

    override bool InputProcess(InputEvent e)
    {
        CheckKeys(e);

        return false;
    }

    ui void Init()
    {
        PlayerInfo player = players[consolePlayer];
        helping = CVar.GetCVar(helpCVar, player).GetBool();
        msgTics = -1;
        isJumpDown = false;
        isForwardDown = false;

        initialized = true;
    }

    ui void CheckCVar()
    {
        PlayerInfo player = players[consolePlayer];
        bool shouldHelp = CVar.GetCVar(helpCVar, player).GetBool();
        bool canHelp = CVar.FindCVar(strafejumpCVar).GetBool() && QuakePlayer(player.mo);

        if (!canHelp)
        {
            helping = false;

            if (shouldHelp)
            {
                msgTics = msgDelay;
                msg = StringStruct.Format(cantMsg, players[consolePlayer].GetUserName());

                CVar.GetCVar(helpCVar, player).SetBool(false);
            }
        }
        else if (!helping && shouldHelp)
        {
            helping = true;
            msgTics = msgDelay;
            msg = StringStruct.Format(onMsg, players[consolePlayer].GetUserName());
        }
        else if (helping && !shouldHelp)
        {
            helping = false;
            msgTics = msgDelay;
            msg = StringStruct.Format(offMsg, players[consolePlayer].GetUserName());
        }
    }

    ui void PrintMsg()
    {
        if (msgTics == 0)
        {
            PlayerInfo player = players[consolePlayer];

            Console.Printf(msg);

            player.mo.A_PlaySound(chatSound, CHAN_Body, 1, ATTN_None, true);
        }
        if (msgTics >= 0) --msgTics;
    }

    ui void CheckKeys(InputEvent e)
    {
        switch (e.type)
        {
        case InputEvent.Type_KeyDown:
            if (IsKeyForCommand(e.keyScan, jumpCmd)) isJumpDown = true;
            else if (IsKeyForCommand(e.keyScan, forwardCmd)) isForwardDown = true;
            break;
        case InputEvent.Type_KeyUp:
            if (IsKeyForCommand(e.keyScan, jumpCmd)) isJumpDown = false;
            else if (IsKeyForCommand(e.keyScan, forwardCmd)) isForwardDown = false;
            break;
        }
    }

    ui void CheckStrafejump()
    {
        EventHandler.SendNetworkEvent("strafejump", (helping && isJumpDown && isForwardDown));
    }

    ui bool IsKeyForCommand(int keyScan, String cmd)
    {
        int k1, k2;
        [k1, k2] = Bindings.GetKeysForCommand(cmd);
        return keyScan == k1 || keyScan == k2;
    }

    ui bool IsOnGround(Actor mo)
    {
        return mo.pos.z <= mo.floorZ;
    }


    bool isStrafejumping[maxPlayers];
    bool hasTurned[maxPlayers];
    bool turnRight[maxPlayers];
    double turnAngle[maxPlayers];
    int turnTics[maxPlayers];


    override void WorldTick()
    {
        for (int i = 0; i < maxPlayers; ++i)
        {
            if (isStrafejumping[i]) Strafejump(i);
            if (turnTics[i]) TurnTick(i);
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (e.name ~== "strafejump") isStrafejumping[e.player] = e.args[0];
    }

    void Strafejump(int i)
    {
        PlayerInfo player = players[i];
        bool onGround = player.mo.pos.z <= player.mo.GetZAt();

        //player.cmd.sideMove = turnRight[i] ? maxSideMove : -maxSideMove;

        if (!onGround)
        {
            player.cmd.buttons &= ~BT_Jump;  // Release jump while in air

            if (!hasTurned[i])
            {
                Vector3 velUnit = player.mo.vel.Unit();
                double intended = VectorAngle(velUnit.x, velUnit.y);
                double angle = FindOptimalAngle(QuakePlayer(player.mo), intended, turnRight[i]);

                TurnPlayer(i, angle);
                hasTurned[i] = true;
            }
        }
        else
        {
            hasTurned[i] = false;
            turnRight[i] = !turnRight[i];
        }
    }

    double FindOptimalAngle(QuakePlayer mo, double intended, bool right)
    {
        Vector3 realVel = mo.vel;
        double realAngle = mo.angle;
        double realZ = mo.pos.z;

        mo.vel.z = 0;
        mo.SetZ(mo.GetZAt());

        double bestAngle;
        double bestSpeed;

        for (double i = 0; i < 90; ++i)
        {
            mo.angle = intended + (right ? -i : i);
            mo.WalkMove();

            double speed = mo.vel.xy dot Actor.AngleToVector(intended);

            if (speed > bestSpeed)
            {
                bestAngle = mo.angle;
                bestSpeed = speed;
            }

            mo.vel.xy = realVel.xy;
            mo.angle = realAngle;
        }

        mo.SetZ(realZ);
        mo.vel = realVel;

        return bestAngle;
    }

    void TurnPlayer(int i, double angle, int tics = defaultTurnTics)
    {
        turnAngle[i] = angle;
        turnTics[i] = tics;
    }

    void TurnTick(int i)
    {
        double angle = players[i].mo.angle;
        double dt = (turnAngle[i] - angle) / turnTics[i];

        players[i].mo.angle += dt;
        --turnTics[i];
    }
}