class LandKickHandler : EventHandler
{
    const landKickCVar = "CG_LandKick";
    const deflectTime = 0.1 * Thinker.ticRate;
    const returnTime = 0.4 * Thinker.ticRate;
    const landSpeed = 8;
    const fallShort = -8;
    const fallMedium = -16;
    const fallFar = -24;

    double zVels[maxPlayers];

    override void WorldTick()
    {
        for (int i = 0; i < maxPlayers; ++i)
        {
            if (!playerInGame[i]) continue;

            let player = players[i].mo.player;
            let mo = player.mo;

            if (player.onGround && zVels[i] <= -landSpeed)
            {
                let k = Kicker(Actor.Spawn("Kicker"));
                k.deflectTime = deflectTime;
                k.returnTime = returnTime;

                double up;
                if (zVels[i] <= -mo.fallingScreamMinSpeed) up = fallFar;
                else if (zVels[i] <= -mo.gruntSpeed) up = fallMedium;
                else up = fallShort;

                double landKick = CVar.GetCVar(landKickCVar, player).GetFloat();
                up *= landKick;

                k.up = up;
                k.weaponOfs.y = -up;

                mo.AddInventory(k);
            }

            zVels[i] = mo.vel.z;
        }
    }
}