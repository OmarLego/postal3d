class Footstep : Actor
{
    enum EWaterLevel
    {
        WL_NotInWater   = 0,
        WL_Feet         = 1,
        WL_Waist        = 2,
        WL_Eyes         = 3
    }

    override void PostBeginPlay()
    {
        if (master.player)
        {
            String stepSound;

            if (master.waterLevel == WL_NotInWater)
            {
                if (master.player.onGround && master.player.vel.Length() > master.speed * 0.6)
                {
                    stepSound = "*step";
                }
            }
            else if (master.waterLevel == WL_Feet)
            {
                if (master.player.onGround) stepSound = "*splash";
                else stepSound = "*swim";
            }
            else if (master.waterLevel == WL_Waist)
            {
                stepSound = "*swim";
            }

            master.A_PlaySound(stepSound);
        }

        Destroy();
    }
}