class DamageKickHandler : EventHandler
{
    const damageKickCVar = "CG_DamageKick";
    const deflectTime = 0.1 * Thinker.ticRate;
    const returnTime = 0.4 * Thinker.ticRate;

    override void WorldThingDamaged(WorldEvent e)
    {
        let mo = e.thing;
        if (!mo.player) return;

        let k = Kicker(Actor.Spawn("Kicker"));
        k.deflectTime = deflectTime;
        k.returnTime = returnTime;

        double damageKick = CVar.GetCVar(damageKickCVar, mo.player).GetFloat();
        double scale = 40.0 / mo.health;
        double kick = Clamp(e.damage * scale, 5, 10) * damageKick;

        if (e.inflictor)
        {
            Vector3 dir = (e.inflictor.pos - mo.pos).Unit();

            Vector3 forward = (Cos(mo.pitch) * Cos(mo.angle), Cos(mo.pitch) * Sin(mo.angle), -Sin(mo.pitch));
            Vector3 right = (Actor.AngleToVector(mo.angle - 90), 0);

            k.roll = -kick * (dir dot right);
            k.pitch = -kick * (dir dot forward);
        }
        else    // Environmental damage
        {
            k.roll = 0;
            k.pitch = -kick;
        }

        mo.AddInventory(k);
    }
}