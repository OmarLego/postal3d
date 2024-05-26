class Kicker : Inventory
{
    int deflectTime;
    int returnTime;

    double angle;
    double pitch;
    double roll;
    double up;
    Vector2 weaponOfs;

    override void Tick()
    {
        if (!owner || !owner.player) return;

        let psp = owner.player.GetPSprite(PSprite.Weapon);

        double age = gameTic - spawnTime;
        if (age < deflectTime)
        {
            owner.A_SetAngle(owner.angle + angle / deflectTime, SPF_Interpolate);
            owner.A_SetPitch(owner.pitch + pitch / deflectTime, SPF_Interpolate);
            owner.A_SetRoll(owner.roll + roll / deflectTime, SPF_Interpolate);

            owner.player.viewHeight += up / deflectTime;

            psp.x += weaponOfs.x * age / deflectTime;
            psp.y += weaponOfs.y * age / deflectTime;
        }
        else if (age < deflectTime + returnTime)
        {
            owner.A_SetAngle(owner.angle - angle / returnTime, SPF_Interpolate);
            owner.A_SetPitch(owner.pitch - pitch / returnTime, SPF_Interpolate);
            owner.A_SetRoll(owner.roll - roll / returnTime, SPF_Interpolate);

            owner.player.viewHeight -= up / returnTime;

            psp.x += weaponOfs.x * (1.0 - (age - deflectTime) / returnTime);
            psp.y += weaponOfs.y * (1.0 - (age - deflectTime) / returnTime);
        }
        else
        {
            Destroy();
        }
    }
}
