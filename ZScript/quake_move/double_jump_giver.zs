class DoubleJumpGiver : Inventory
{
    Property MaxJumps : maxJumps;
    Property JumpStrength : jumpStrength;

    Default
    {
        Inventory.MaxAmount 1;

        DoubleJumpGiver.MaxJumps 2;
        DoubleJumpGiver.JumpStrength 1;
    }

    int maxJumps;
    double jumpStrength;

    int jumpCount;

    override void Tick()
    {
        Super.Tick();

        if (!owner || !owner.player) return;

        let player = owner.player;
        let mo = player.mo;
        UserCmd cmd = player.cmd;

        if (player.onGround) jumpCount = 0;

        if (jumpCount < maxJumps && JustPressed(player, BT_Jump))
        {
            if (jumpCount > 0)
            {
                mo.vel.z = jumpStrength * mo.jumpZ;
                mo.A_PlaySound("*jump");
            }

            ++jumpCount;
        }
    }

    bool JustPressed(PlayerInfo player, int bt)
    {
        return (player.cmd.buttons & bt) && !(player.oldButtons & bt);
    }
}