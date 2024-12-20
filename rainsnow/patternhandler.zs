class WeatherPattern
{
    private bool bPrevType;
    private Name weatherType;
    private bool bPrevTics;
    private int minTics, maxTics;
    private WeatherPattern next;
    private int jumpChance;
    private Array<Name> jumpLabels;

    static WeatherPattern Create(Name weatherType, int minTics, int maxTics, bool bPrevType = false, bool bPrevTics = false)
    {
        let wp = new("WeatherPattern");
        wp.weatherType = weatherType;
        wp.minTics = minTics;
        wp.maxTics = maxTics;
        wp.bPrevType = bPrevType;
        wp.bPrevTics = bPrevTics;

        return wp;
    }

    void SetNext(WeatherPattern nextPattern)
    {
        next = nextPattern;
    }

    void SetJumpChance(int chance, Array<Name> labels)
    {
        jumpChance = chance;
        jumpLabels.Copy(labels);
    }

    bool, Name DidJump()
    {
        if (jumpLabels.Size() && Random[WeatherPattern]() < jumpChance)
            return true, jumpLabels[Random[WeatherPattern](0, jumpLabels.Size()-1)];

        return false, 'None';
    }

    Name, int GetStateInfo(WeatherPattern prev = null)
    {
        if (bPrevType)
            weatherType = prev ? prev.GetType() : 'None';

        if (bPrevTics)
        {
            if (prev)
                [minTics, maxTics] = prev.GetTics();
            else
                minTics = maxTics = -1;
        }

        return weatherType, minTics != maxTics ? Random[WeatherPattern](minTics, maxTics) : minTics;
    }

    clearscope Name GetType() const
    {
        return weatherType;
    }

    clearscope int, int GetTics() const
    {
        return minTics, maxTics;
    }

    clearscope WeatherPattern GetNext() const
    {
        return next;
    }
}

class WeatherPatternTracker play
{
    private Map<Name, WeatherPattern> patternLabels;
    private WeatherPattern curPattern;
    private int curTics;
    private bool bStarted;

    void SetLabel(Name label, WeatherPattern pattern)
    {
        patternLabels.Insert(label, pattern);
    }

    WeatherPattern GetLabel(Name label) const
    {
        return patternLabels.GetIfExists(label);
    }

    void Start()
    {
        if (bStarted)
        {
            if (curPattern)
                Weather.SetPrecipitationType(curPattern.GetStateInfo(curPattern));
            else
                Weather.SetPrecipitationType('None');

            return;
        }

        bStarted = true;
        SetPatternLabel('Start');
    }

    void TickPattern()
    {
        if (curPattern && curTics >= 0 && --curTics <= 0)
            SetPattern(curPattern.GetNext());
    }

    void SetPatternLabel(Name label)
    {
        SetPattern(GetLabel(label));
    }

    void SetPattern(WeatherPattern pattern)
    {
        if (!pattern)
        {
            curPattern = null;
            Weather.SetPrecipitationType('None');
            curTics = 0;
            return;
        }

        let [didJump, label] = pattern.DidJump();
        if (didJump)
        {
            SetPatternLabel(label);
            return;
        }

        let [type, tics] = pattern.GetStateInfo(curPattern);
        curPattern = pattern;
        Weather.SetPrecipitationType(type);
        curTics = tics;
        if (!curTics)
            SetPattern(curPattern.GetNext());
    }
}

class PendingLabel
{
    private Name label;
    private Array<Name> fromLabels;
    private WeatherPattern pattern;

    static PendingLabel Create(Name label, Array<Name> fromLabels, WeatherPattern pattern)
    {
        let pl = new("PendingLabel");
        pl.label = label;
        pl.fromLabels.Copy(fromLabels);
        pl.pattern = pattern;

        return pl;
    }

    clearscope Name, WeatherPattern GetPending() const
    {
        return label, pattern;
    }

    clearscope void GetFrom(out Array<Name> labels) const
    {
        labels.Copy(fromLabels);
    }
}

class WeatherPatternHandler : StaticEventHandler
{
    const DECLARE_MAP = "map";
    const DECLARE_CLUSTER = "cluster";
    const DECLARE_LABEL = ":";
    const BLOCK_START = "{";
    const BLOCK_CLOSE = "}";
    const STATEMENT_CLOSE = ";";
    const ARG_START = "(";
    const ARG_CLOSE = ")";
    const ARG_DELIM = ",";
    const PATTERN_BLANK = "TNT1";
    const PATTERN_PREV = "####";
    const PATTERN_PREV_DUR = "#";
    const PATTERN_RANDOM = "Random";
    const PATTERN_JUMP = "A_Jump";

    private Map<Name, WeatherPatternTracker> mapPatterns;
    private Map<int, WeatherPatternTracker> clusterPatterns;
    private WeatherPatternTracker curPattern;

    static clearscope WeatherPatternHandler Get()
    {
        return WeatherPatternHandler(Find("WeatherPatternHandler"));
    }

    void InitializePattern()
    {
        curPattern = mapPatterns.GetIfExists(level.mapName);
        if (!curPattern)
        {
            curPattern = clusterPatterns.GetIfExists(level.cluster);
            if (!curPattern)
                curPattern = mapPatterns.GetIfExists('None');
        }

        if (curPattern)
            curPattern.Start();
    }

    void TickPattern()
    {
        if (curPattern)
            curPattern.TickPattern();
    }

    void ClearPattern()
    {
        curPattern = null;
    }

    clearscope bool HasPattern() const
    {
        return curPattern != null;
    }

    override void OnEngineInitialize()
    {
        Array<string> symbols;
        symbols.PushV(BLOCK_START, BLOCK_CLOSE, STATEMENT_CLOSE, ARG_START, ARG_CLOSE, ARG_DELIM);
        let reader = WeatherStreamReader.Create("WTHRPTRN", symbols);
		while (reader.NextLump())
        {
            while (!reader.AtEndOfStream())
            {
                ParsePattern(reader);
                if (reader.HasError())
                {
                    reader.PrintError();
                    break;
                }
            }
        }
    }

    private void ParsePattern(WeatherStreamReader reader)
    {
        if (!reader.NextLexeme())
            return;

        Name mapName;
        int cluster;
        bool isCluster;
        string word = reader.GetLexeme();
        if (word != BLOCK_START)
        {
            if (reader.IsReserved(word) || (!(word ~== DECLARE_MAP) && !(word ~== DECLARE_CLUSTER)))
            {
                reader.ThrowExpectationError("cluster or map declaration");
                return;
            }

            isCluster = word ~== DECLARE_CLUSTER;
            if (isCluster)
            {
                if (!reader.ExpectNonreserved())
                {
                    reader.ThrowExpectationError("cluster number");
                    return;
                }

                cluster = reader.GetLexeme().ToInt();
            }
            else
            {
                if (!reader.ExpectNonreserved())
                {
                    reader.ThrowExpectationError("map name");
                    return;
                }

                mapName = reader.StripQuotes();
            }

            if (!reader.ExpectLexeme(BLOCK_START))
            {
                reader.ThrowExpectationError(BLOCK_START);
                return;
            }
        }

        let wpt = new("WeatherPatternTracker");
        Array<PendingLabel> pending;
        bool closed;

        bool parsedFirstLabel;
        WeatherPattern prev;
        Array<Name> curLabel;
        while (reader.NextLexeme())
        {
            string typeWord = reader.GetLexeme();
            if (typeWord == BLOCK_CLOSE)
            {
                closed = true;
                break;
            }

            if (reader.IsReserved(typeWord))
            {
                reader.ThrowExpectationError("pattern label or pattern state");
                return;
            }

            if (typeWord.Mid(typeWord.Length()-1) == DECLARE_LABEL)
            {
                Name newLabel = typeWord.Left(typeWord.Length()-1);
                if (IsStateJump(newLabel))
                {
                    reader.ThrowError("Invalid label "..newLabel);
                    return;
                }

                if (parsedFirstLabel)
                {
                    parsedFirstLabel = false;
                    curLabel.Clear();
                }
                
                curLabel.Push(newLabel);
                continue;
            }

            if (!curLabel.Size())
            {
                reader.ThrowError("Attempted to declare a pattern state outside of a valid label");
                return;
            }

            if (IsStateJump(typeWord))
            {
                switch (Name(typeWord))
                {
                    case 'Goto':
                        if (!ExpectNonDirective(reader, "label name"))
                            return;
                        pending.Push(PendingLabel.Create(reader.GetLexeme(), curLabel, prev));
                        break;

                    case 'Stop':
                        if (prev)
                            prev.SetNext(null);
                        break;

                    case 'Loop':
                        let start = wpt.GetLabel(curLabel[0]);
                        if (!start)
                        {
                            reader.ThrowError("Attempted to loop with no valid pattern state");
                            return;
                        }
                        prev.SetNext(start);
                        break;

                    case 'Wait':
                        if (!prev)
                        {
                            reader.ThrowError("Attempted to wait with no valid pattern state");
                            return;
                        }
                        prev.SetNext(prev);
                        break;
                }

                prev = null;
                parsedFirstLabel = false;
                curLabel.Clear();
                if (!reader.ExpectLexeme(STATEMENT_CLOSE))
                {
                    reader.ThrowExpectationError(STATEMENT_CLOSE);
                    return;
                }

                continue;
            }

            Name type = 'None';
            bool usePrevType = false;
            if (typeWord == PATTERN_PREV)
                usePrevType = true;
            else if (!(typeWord ~== PATTERN_BLANK))
                type = reader.StripQuotes();

            if (!ExpectNonDirective(reader, "pattern state duration"))
                return;

            int minTics, maxTics;
            bool usePrevTics = false;
            string dur = reader.GetLexeme();
            if (dur == PATTERN_PREV_DUR)
            {
                usePrevTics = true;
                minTics = maxTics = -1;
            }
            else if (dur ~== PATTERN_RANDOM)
            {
                if (!reader.ExpectLexeme(ARG_START))
                {
                    reader.ThrowExpectationError(ARG_START);
                    return;
                }

                if (!ExpectNonDirective(reader, "minimum duration"))
                    return;

                minTics = int(ceil(reader.GetLexeme().ToDouble() * gameTicRate));

                if (!reader.ExpectLexeme(ARG_DELIM))
                {
                    reader.ThrowExpectationError(ARG_DELIM);
                    return;
                }

                if (!ExpectNonDirective(reader, "maximum duration"))
                    return;

                maxTics = int(ceil(reader.GetLexeme().ToDouble() * gameTicRate));

                if (!reader.ExpectLexeme(ARG_CLOSE))
                {
                    reader.ThrowExpectationError(ARG_CLOSE);
                    return;
                }
            }
            else
            {
                minTics = int(ceil(dur.ToDouble() * gameTicRate));
                maxTics = minTics;
            }

            let cur = WeatherPattern.Create(type, minTics, maxTics, usePrevType, usePrevTics);
            if (!parsedFirstLabel)
            {
                parsedFirstLabel = true;
                foreach (cl : curLabel)
                    wpt.SetLabel(cl, cur);
            }

            if (prev)
                prev.SetNext(cur);

            prev = cur;

            if (!reader.NextLexeme())
            {
                reader.ThrowExpectationError(STATEMENT_CLOSE.." or "..PATTERN_JUMP);
                return;
            }

            string endWord = reader.GetLexeme();
            if (endWord == STATEMENT_CLOSE)
                continue;

            if (!(endWord ~== PATTERN_JUMP))
            {
                reader.ThrowExpectationError(PATTERN_JUMP);
                return;
            }

            if (!reader.ExpectLexeme(ARG_START))
            {
                reader.ThrowExpectationError(ARG_START);
                return;
            }

            if (!ExpectNonDirective(reader, "jump chance"))
                return;

            int jumpChance = reader.GetLexeme().ToInt();
            if (!reader.ExpectLexeme(ARG_DELIM))
            {
                reader.ThrowExpectationError(ARG_DELIM);
                return;
            }

            Array<Name> jumpLabels;
            while (true)
            {
                if (!ExpectNonDirective(reader, "jump label"))
                    return;

                jumpLabels.Push(reader.GetLexeme());
                if (!reader.NextLexeme())
                {
                    reader.ThrowExpectationError(ARG_DELIM.." or "..ARG_CLOSE);
                    return;
                }

                string param = reader.GetLexeme();
                if (param != ARG_DELIM && param != ARG_CLOSE)
                {
                    reader.ThrowExpectationError(ARG_DELIM.." or "..ARG_CLOSE);
                    return;
                }

                if (param == ARG_CLOSE)
                    break;
            } 

            prev.SetJumpChance(jumpChance, jumpLabels);

            if (!reader.ExpectLexeme(STATEMENT_CLOSE))
            {
                reader.ThrowExpectationError(STATEMENT_CLOSE);
                return;
            }
        }

        if (!closed)
		{
			reader.ThrowExpectationError(BLOCK_CLOSE);
			return;
		}

        if (curLabel.Size())
        {
            reader.ThrowError(String.Format("Label %s was not properly closed", curLabel[0]));
            return;
        }

        foreach (p : pending)
        {
            let [label, pattern] = p.GetPending();
            let next = wpt.GetLabel(label);
            if (!pattern)
            {
                Array<Name> from;
                p.GetFrom(from);

                foreach (fl : from)
                    wpt.SetLabel(fl, next);
            }
            else
            {
                pattern.SetNext(next);
            }
        }

        if (isCluster)
            clusterPatterns.Insert(cluster, wpt);
        else
            mapPatterns.Insert(mapName, wpt);
    }

    private bool ExpectNonDirective(WeatherStreamReader reader, string expecting)
    {
        if (!reader.ExpectNonreserved() || IsStateJump(reader.GetLexeme()))
        {
            reader.ThrowExpectationError(expecting);
            return false;
        }

        return true;
    }

    private bool IsStateJump(Name st)
    {
        static const Name jumps[] = { 'Goto', 'Loop', 'Wait', 'Stop' };

        foreach (jump : jumps)
        {
            if (st == jump)
                return true;
        }

        return false;
    }
}
