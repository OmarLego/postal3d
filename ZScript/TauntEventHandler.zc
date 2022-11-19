class SaySomethingOnKill : EventHandler
{
    const CHAN_TAUNT = 42; //taunt sound channel id
    
    const TAUNTDELAY = 200;
    const TAUNTCHANCE = 85;    
    
    transient int lastTauntTic;
    transient int lastKillTic;
    int totalkills;
    int prevTotalKills;
    
    // A simple wrapper function to play the taunt sound.
    // If the 'local' argument is true, other players
    // won't hear your taunts in multiplayer.
    void PlayTaunt(sound snd, actor who, bool local = true)
    {
        if (!who || !who.player)
            return;
        if (local && who.player != players[consoleplayer])
            return;
        who.A_StartSound(snd, CHAN_VOICE, CHANF_NOSTOP|CHANF_UI);
    }
    
    override void WorldThingDied(worldEvent e)
    {
        if (e.thing && e.thing.bISMONSTER && e.thing.target && e.thing.target.player)
        {
            totalkills++;
            let ppawn = e.thing.target;
            
            if ((lastTauntTic <= 0 || level.time - lastTauntTic >= TAUNTDELAY) && random[tsnd](1, 100) <= TAUNTCHANCE)
            {
                PlayTaunt("DudeTalk", ppawn);
                lastTauntTic = level.time;
            }
            
            lastKillTic = level.time;
        }
    }
}