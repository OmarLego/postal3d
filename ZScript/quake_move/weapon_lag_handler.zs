class WeaponLagHandler : EventHandler
{
    const sensitivityXCvar = "CG_LagSensitivityX";
    const sensitivityYCvar = "CG_LagSensitivityY";
    const recenterXCvar = "CG_LagRecenterX";
    const recenterYCvar = "CG_LagRecenterY";
    const minXCvar = "CG_LagMinX";
    const maxXCvar = "CG_LagMaxX";
    const minYCvar = "CG_LagMinY";
    const maxYCvar = "CG_LagMaxY";
    const offsetYCvar = "CG_LagOffsetY";

    const maxInput = 65536;
    const pSpriteX = 0;
    const pSpriteY = 32;

    Vector2 lagOffsets[maxPlayers];

    override void WorldTick()
    {
        for (int i = 0; i < maxPlayers; ++i)
        {
            if (!playerInGame[i]) continue;

            let player = players[i].mo.player;
            let weapon = player.readyWeapon;
            let psp = player.GetPSprite(PSprite.Weapon);
            UserCmd cmd = player.cmd;

            double sensitivityX = CVar.GetCVar(sensitivityXCVar, player).GetFloat();
            double sensitivityY = CVar.GetCVar(sensitivityYCVar, player).GetFloat();
            double recenterX = CVar.GetCVar(recenterXCVar, player).GetFloat();
            double recenterY = CVar.GetCVar(recenterYCVar, player).GetFloat();
            double minX = CVar.GetCVar(minXCVar, player).GetFloat();
            double maxX = CVar.GetCVar(maxXCVar, player).GetFloat();
            double minY = CVar.GetCVar(minYCVar, player).GetFloat();
            double maxY = CVar.GetCVar(maxYCVar, player).GetFloat();
            double offsetY = CVar.GetCVar(offsetYCVar, player).GetFloat();

            lagOffsets[i] += (sensitivityX * cmd.yaw / maxInput, sensitivityY * cmd.pitch / maxInput);
            lagOffsets[i] -= (recenterX * lagOffsets[i].x, recenterY * lagOffsets[i].y);
            lagOffsets[i] = (Clamp(lagOffsets[i].x, minX, maxX), Clamp(lagOffsets[i].y, minY, MaxY));

            if (!weapon.InStateSequence(psp.curState, weapon.GetReadyState()))    // Can only sway in Ready state
            {
                // Recenter weapon during fire state, but
                // Keep weapon from jerking up on last frame of up animation
                if (!weapon.InStateSequence(psp.curState, weapon.GetUpState())) lagOffsets[i] = (pSpriteX, pSpriteY);

                continue;
            }

            psp.x = lagOffsets[i].x + pSpriteX;
            psp.y = lagOffsets[i].y + pSpriteY + offsetY;
        }
    }
}