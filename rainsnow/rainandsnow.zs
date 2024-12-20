class Rain : Precipitation
{
	Default
	{
		RenderStyle "Add";
		Alpha 0.5;
		XScale 0.25;
		VSpeed -48;
		
		+FORCEYBILLBOARD
	}
	
	States
	{
		Spawn:
			RAIN A 15;
			Stop;
		
		Death:
			RAIN A 1;
			TNT1 A 0
			{
				scale = (0.2,0.2);
				bForceYBillboard = false;
				bForceXYBillboard = true;
			}
			RAIN BCDE 1;
			Stop;
	}
}

class BloodRain : Rain
{
	Default
	{
		Translation "0:255=176:191";
	}
}

class Snow : Precipitation
{
	Default
	{
		RenderStyle "Translucent";
		Alpha 0.9;
		Gravity 0.02;
		
		+FORCEXYBILLBOARD
	}
	
	States
	{
		Death:
			SNOW A 1;
			Stop;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		A_SetScale(FRandom[Snow](0.25,0.5));
	}
}

class LightSnow : Snow
{
	Default
	{
		VSpeed -4;
	}
	
	States
	{
		Spawn:
			SNOW A 140;
			Stop;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		VelFromAngle(FRandom[Snow](0,1), FRandom[Snow](0,360));
	}
}

class LightAsh : LightSnow
{
	Default
	{
		Translation "0:255=9:15";
		
		+BRIGHT
	}
}

class MediumSnow : Snow
{
	Default
	{
		VSpeed -8;
	}
	
	States
	{
		Spawn:
			SNOW A 70;
			Stop;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		VelFromAngle(FRandom[Snow](2,3), FRandom[Snow](0,360));
	}
}

class HeavySnow : Snow
{
	Default
	{
		VSpeed -16;
	}
	
	States
	{
		Spawn:
			SNOW A 35;
			Stop;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		VelFromAngle(FRandom[Snow](7,10), FRandom[Snow](20,30));
	}
}

class HeavyAsh : HeavySnow
{
	Default
	{
		Translation "0:255=9:15";
		
		+BRIGHT
	}
}

class RainAndSnow : Weather
{
	private WeatherHandler wh;
	
	Array<string> weatherTypes;
	Array<string> intensityTypes;
	
	override void BeginPlay()
	{
		super.BeginPlay();
		
		intensityTypes.PushV("Min", "Med", "Max");
		weatherTypes.Push("");

		wh = WeatherHandler(StaticEventHandler.Find("WeatherHandler"));
		if (wh)
		{
			for (int i = 0; i < wh.precipTypes.Size(); ++i)
			{
				string n = String.Format(wh.precipTypes[i].GetName()).Mid(3);
				if (weatherTypes.Find(n) >= weatherTypes.Size())
					weatherTypes.Push(n);
			}
		}
	}
	
	void SetWeather(int w, int i, bool message = true)
	{
		w = clamp(w, 0, weatherTypes.Size()-1);
		i = clamp(i, 0, intensityTypes.Size()-1);
		
		string weath = weatherTypes[w];
		if (!weath.Length())
		{
			Weather.SetPrecipitationType(weath);
		}
		else
		{
			string inten = intensityTypes[i];
			if (wh)
			{
				int index = i;
				do
				{
					inten = intensityTypes[index];
					let pt = wh.FindType(inten..weath);
					if (pt)
						break;
					
					--index;
					if (index < 0)
						index = intensityTypes.Size()-1;
				} while (index != i)
			}
			
			Weather.SetPrecipitationType(inten..weath);
		}
		
		if (message)
		{
			string m = Weather.GetPrecipitationTypeTag();
			if (!m.Length())
				m = StringTable.Localize("$WTHR_SUNNY");
			
			Console.PrintF(m);
		}
	}
}

class RainAndSnowHandler : StaticEventHandler
{
	const CUR_WEATHER = "rs_weather";
	const CUR_INTENSITY = "rs_intensity";
	const DISABLE_PATTERN = "rs_disablepatterns";

	private WeatherPatternHandler patternHandler;
	private RainAndSnow rs;
	private bool prevDisable;
	private int prevWeather;
	private int prevIntensity;
	
	override void WorldLoaded(WorldEvent e)
	{
		rs = null;
		let wthr = Weather.Get();
		if (wthr is "RainAndSnow")
			rs = RainAndSnow(wthr);
		else if (!wthr)
			rs = RainAndSnow(Actor.Spawn("RainAndSnow"));

		if (!rs)
			return;

		patternHandler = WeatherPatternHandler.Get();
		prevDisable = CVar.GetCVar(DISABLE_PATTERN, players[consolePlayer]).GetBool();
		if (prevDisable)
			patternHandler.ClearPattern();
		else
			patternHandler.InitializePattern();
		
		prevWeather = CVar.GetCVar(CUR_WEATHER, players[consolePlayer]).GetInt();
		prevIntensity = CVar.GetCVar(CUR_INTENSITY, players[consolePlayer]).GetInt();
		if (!patternHandler.HasPattern())
			rs.SetWeather(prevWeather, prevIntensity, false);
	}
	
	override void WorldTick()
	{
		if (!rs)
			return;

		bool forceSet;
		bool curDisable = CVar.GetCVar(DISABLE_PATTERN, players[consolePlayer]).GetBool();
		if (curDisable)
		{
			forceSet = patternHandler.HasPattern();
			patternHandler.ClearPattern();
		}
		else if (prevDisable)
		{
			patternHandler.InitializePattern();
		}

		patternHandler.TickPattern();

		int curWeath = CVar.GetCVar(CUR_WEATHER, players[consolePlayer]).GetInt();
		int curInten = CVar.GetCVar(CUR_INTENSITY, players[consolePlayer]).GetInt();
		if (forceSet || curWeath != prevWeather || curInten != prevIntensity)
			rs.SetWeather(curWeath, curInten);
		
		prevDisable = curDisable;
		prevWeather = curWeath;
		prevIntensity = curInten;
	}
	
	void ToggleWeather(bool prev = false)
	{
		if (!rs)
			return;

		let disable = CVar.GetCVar(DISABLE_PATTERN, players[consolePlayer]);
		if (!disable.GetBool())
		{
			disable.SetBool(true);
			return;
		}

		let weath = CVar.GetCVar(CUR_WEATHER, players[consolePlayer]);
		if (prev)
		{
			weath.SetInt(weath.GetInt()-1);
			if (weath.GetInt() < 0)
				weath.SetInt(rs.weatherTypes.Size()-1);
		}
		else
		{
			weath.SetInt(weath.GetInt()+1);
			if (weath.GetInt() >= rs.weatherTypes.Size())
				weath.SetInt(0);
		}
	}
	
	void ToggleIntensity(bool prev = false)
	{
		if (!rs)
			return;

		let disable = CVar.GetCVar(DISABLE_PATTERN, players[consolePlayer]);
		if (!disable.GetBool())
		{
			disable.SetBool(true);
			return;
		}
		
		let intensity = CVar.GetCVar(CUR_INTENSITY, players[consolePlayer]);
		if (prev)
		{
			intensity.SetInt(intensity.GetInt()-1);
			if (intensity.GetInt() < 0)
				intensity.SetInt(rs.intensityTypes.Size()-1);
		}
		else
		{
			intensity.SetInt(intensity.GetInt()+1);
			if (intensity.GetInt() >= rs.intensityTypes.Size())
				intensity.SetInt(0);
		}
	}
	
	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.player != consolePlayer || !rs)
			return;
		
		if (e.name ~== "NextWeather")
			ToggleWeather();
		else if (e.name ~== "PrevWeather")
			ToggleWeather(true);
		else if (e.name ~== "NextIntensity")
			ToggleIntensity();
		else if (e.name ~== "PrevIntensity")
			ToggleIntensity(true);
	}
}
