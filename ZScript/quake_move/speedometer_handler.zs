class SpeedometerHandler : EventHandler
{
    const spdCVar = "CG_Speedometer";
    const fmt = "%d UPS";
    const xPad = 4;
    const yPad = 2;
    const col = Font.CR_Untranslated;
    const updateTics = 4;

    ui double dt;
    ui int spd;

    override void RenderOverlay(RenderEvent e)
    {
        PlayerInfo player = players[consolePlayer];
        bool shouldDraw = CVar.GetCVar(spdCVar, player).GetBool();
        if (shouldDraw)
        {
            dt += e.fracTic;
            if (dt >= updateTics)
            {
                spd = player.mo.vel.xy.Length() * Thinker.ticRate;
                dt = 0;
            }

            String text = StringStruct.Format(fmt, spd);
            Vector2 pos = (
                Screen.GetWidth() - cleanXFac * (smallFont.StringWidth(text) + xPad),
                cleanYFac * yPad);

            Screen.DrawText(smallFont, col, pos.x, pos.y, text, DTA_CleanNoMove, true);
        }
    }
}