/* Copyright Alexander Kromm (mmaulwurff@gmail.com) 2019-2021
 *
 * This file is part of Target Spy.
 *
 * Target Spy is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * Target Spy is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * Target Spy.  If not, see <https://www.gnu.org/licenses/>.
 */

class ts_Settings
{

  enum FrameStyles
  {
    FRAME_DISABLED,
    FRAME_SLASH,
    FRAME_DOTS,
    FRAME_LESS_GREATER,
    FRAME_GREATER_LESS,
    FRAME_BARS,
    FRAME_GRAPHIC,
    FRAME_GRAPHIC_RED,
  };

  enum BarsOnTargetPosition
  {
    ON_TARGET_DISABLED,
    ON_TARGET_ABOVE,
    ON_TARGET_BELOW,
  }

  static
  ts_Settings from()
  {
    let result = new("ts_Settings");
    result.initialize();
    return result;
  }

  /// i must be from [0, 11]
  int    colors         (int i) { return _colors[i].getInt(); }

  bool   showKillConfirmation() { return _showKillConfirmation.getBool(); }
  bool   namedConfirmation   () { return _namedConfirmation   .getBool(); }
  bool   isEnabled           () { return _isEnabled           .getBool(); }

  int    minHealth           () { return _minHealth           .getInt(); }
  double yStart              () { return _yStart              .getDouble(); }
  double yOffset             () { return _yOffset             .getDouble(); }
  bool   logScale            () { return _logScale            .getBool(); }
  bool   showBar             () { return _showBar             .getBool(); }
  bool   showName            () { return _showName            .getBool(); }
  bool   showNameAndTag      () { return _showNameAndTag      .getBool(); }
  int    showNums            () { return _showNums            .getInt(); }
  bool   showInfo            () { return _showInfo            .getBool(); }
  bool   showCorps           () { return _showCorps           .getBool(); }
  bool   crossOn             () { return _crossOn             .getBool(); }
  int    crossCol            () { return _crossCol            .getInt(); }
  int    nameCol             () { return _nameCol             .getInt(); }
  int    weakCol             () { return _weakCol             .getInt(); }
  bool   altHpCols           () { return _altHpCols           .getBool(); }
  bool   almDeadCr           () { return _almDeadCr           .getBool(); }
  int    crAlmDead           () { return _crAlmDead           .getInt(); }

  double crossOff            () { return _crossOff            .getDouble(); }
  double topOff              () { return _topOff              .getDouble(); }
  double botOff              () { return _botOff              .getDouble(); }

  int    greenCr             () { return _greenCr             .getInt(); }
  int    redCr               () { return _redCr               .getInt(); }

  bool   showChampion        () { return _showChampion        .getBool(); }
  int    showObjects         () { return _showObjects         .getInt(); }
  int    showInternalNames   () { return _showInternalNames   .getInt(); }
  bool   showHidden          () { return _showHidden          .getBool(); }
  bool   showFriends         () { return _showFriends         .getBool(); }
  bool   showDormant         () { return _showDormant         .getBool(); }
  bool   showIdle            () { return _showIdle            .getBool(); }
  bool   hideInDarkness      () { return _hideInDarkness      .getBool(); }
  int    minimalLightLevel   () { return _minimalLightLevel   .getInt(); }

  double crossScale          () { return protectedFromZero(_crossScale.getDouble()); }
  double crossOpacity        () { return _crossOpacity        .getDouble(); }

  bool   hitConfirmation     () { return _hitConfirmation     .getBool(); }
  int    hitColor            () { return _hitColor            .getInt(); }

  double xAdjustment         () { return _xAdjustment         .getDouble(); }
  bool   noCrossOnSlot1      () { return _noCrossOnSlot1      .getBool(); }

  int    frameStyle          () { return _frameStyle          .getInt(); }
  double frameScale          () { return protectedFromZero(_frameScale.getDouble()); }
  double frameSize           () { return _frameSize           .getDouble(); }

  double opacity             () { return _opacity             .getDouble(); }
  double lengthMultiplier    () { return _lengthMultiplier    .getDouble(); }
  int    barsOnTarget        () { return _barsOnTarget        .getInt(); }

  string pip                 () { return _pip                 .getString(); }
  string emptyPip            () { return _emptyPip            .getString(); }
  string fontName            () { return _fontName            .getString(); }
  string crosshair           () { return _crosshair           .getString(); }
  string crossTop            () { return _crossTop            .getString(); }
  string crossBot            () { return _crossBot            .getString(); }
  string crossFontName       () { return _crossFontName       .getString(); }

  double getTextScale()     { return 0.5 / protectedFromZero(_textScale.getDouble()); }
  double getNewlineHeight() { return 0.03 * _stepMultiplier.getDouble(); }

// private: ////////////////////////////////////////////////////////////////////////////////////////

  private static
  double protectedFromZero(double value)
  {
    return value ? value : 1;
  }

  private void initialize()
  {
    _showKillConfirmation = makeCvar("m8f_POts_show_confirm");
    _namedConfirmation    = makeCvar("m8f_POts_named_confirm");
    _isEnabled            = makeCvar("m8f_POts_enabled");

    _minHealth            = makeCvar("m8f_POts_min_health");
    _yStart               = makeCvar("m8f_POts_y");
    _yOffset              = makeCvar("m8f_POts_y_offset");
    _logScale             = makeCvar("m8f_POts_bar_log_scale");
    _showBar              = makeCvar("m8f_POts_show_bar");
    _showName             = makeCvar("m8f_POts_show_name");
    _showNameAndTag       = makeCvar("m8f_POts_show_name_tag");
    _showNums             = makeCvar("m8f_POts_show_numbers");
    _showInfo             = makeCvar("m8f_POts_show_info");
    _showCorps            = makeCvar("m8f_POts_show_corpses");
    _crossOn              = makeCvar("m8f_POts_crosshair_on");
    _crossCol             = makeCvar("m8f_POts_def_color_crs");
    _nameCol              = makeCvar("m8f_POts_def_color_tag");
    _weakCol              = makeCvar("m8f_POts_def_cl_tag_wk");
    _altHpCols            = makeCvar("m8f_POts_alt_hp_color");
    _stepMultiplier       = makeCvar("m8f_POts_step_mult");

    _crAlmDead            = makeCvar("m8f_POts_cr_alm_dead");
    _almDeadCr            = makeCvar("m8f_POts_alm_dead_cr");

    _crossOff             = makeCvar("m8f_POts_cross_offset");
    _topOff               = makeCvar("m8f_POts_top_offset");
    _botOff               = makeCvar("m8f_POts_bot_offset");

    _greenCr              = makeCvar("m8f_POts_green_color");
    _redCr                = makeCvar("m8f_POts_red_color");

    _showChampion         = makeCvar("m8f_POts_show_champion");
    _showObjects          = makeCvar("m8f_POts_show_objects");
    _showInternalNames    = makeCvar("m8fPO_class_as_tag");
    _showHidden           = makeCvar("m8f_POts_show_hidden");
    _showFriends          = makeCvar("m8f_POts_show_friends");
    _showDormant          = makeCvar("m8f_POts_show_dormant");
    _showIdle             = makeCvar("m8f_POts_show_idle");
    _hideInDarkness       = makeCvar("m8f_POts_hide_in_dark");
    _minimalLightLevel    = makeCvar("m8f_POts_light_level");

    _crossScale           = makeCvar("m8f_POts_cross_scale");
    _crossOpacity         = makeCvar("m8f_POts_cr_opacity");

    _hitConfirmation      = makeCvar("m8f_POts_hit_confirm");
    _hitColor             = makeCvar("m8f_POts_hit_color");

    _textScale            = makeCvar("m8f_POts_text_scale");
    _xAdjustment          = makeCvar("m8f_POts_x_adjustment");
    _noCrossOnSlot1       = makeCvar("m8f_POts_no_cross_on_1");

    _frameStyle           = makeCvar("m8f_POts_frame_style");
    _frameScale           = makeCvar("m8f_POts_frame_scale");
    _frameSize            = makeCvar("m8f_POts_frame_size");

    _opacity              = makeCvar("m8f_POts_opacity");
    _lengthMultiplier     = makeCvar("m8f_POts_length_mult");
    _barsOnTarget         = makeCvar("m8f_POts_on_target");

    _pip                  = makeCvar("m8f_POts_pip");
    _emptyPip             = makeCvar("m8f_POts_empty_pip");
    _fontName             = makeCvar("m8f_POts_font");
    _crosshair            = makeCvar("m8f_POts_crosshair");
    _crossTop             = makeCvar("m8f_POts_cross_top");
    _crossBot             = makeCvar("m8f_POts_cross_bottom");
    _crossFontName        = makeCvar("m8f_POts_cr_font");

    for (int i = 0; i < 12; ++i)
    {
      _colors[i] = makeCvar(string.format("m8f_POts_cr_%d", i));
    }
  }

  private static
  ts_Cvar makeCvar(string cvarName)
  {
    return ts_Cvar.from(cvarName);
  }

  private ts_Cvar _showKillConfirmation;
  private ts_Cvar _namedConfirmation;
  private ts_Cvar _isEnabled;

  private ts_Cvar _minHealth;
  private ts_Cvar _yStart;
  private ts_Cvar _yOffset;
  private ts_Cvar _logScale;
  private ts_Cvar _showBar;
  private ts_Cvar _showName;
  private ts_Cvar _showNameAndTag;
  private ts_Cvar _showNums;
  private ts_Cvar _showInfo;
  private ts_Cvar _showCorps;
  private ts_Cvar _crossOn;
  private ts_Cvar _crossCol;
  private ts_Cvar _nameCol;
  private ts_Cvar _weakCol;
  private ts_Cvar _altHpCols;
  private ts_Cvar _stepMultiplier;
  private ts_Cvar _almDeadCr;
  private ts_Cvar _crAlmDead;
  private ts_Cvar _crossOff;
  private ts_Cvar _topOff;
  private ts_Cvar _botOff;
  private ts_Cvar _greenCr;
  private ts_Cvar _redCr;

  private ts_Cvar _showChampion;
  private ts_Cvar _showObjects;
  private ts_Cvar _showInternalNames;
  private ts_Cvar _showHidden;
  private ts_Cvar _showFriends;
  private ts_Cvar _showDormant;
  private ts_Cvar _showIdle;
  private ts_Cvar _hideInDarkness;
  private ts_Cvar _minimalLightLevel;

  private ts_Cvar _crossScale;
  private ts_Cvar _crossOpacity;

  private ts_Cvar _hitConfirmation;
  private ts_Cvar _hitColor;

  private ts_Cvar _textScale;
  private ts_Cvar _xAdjustment;
  private ts_Cvar _noCrossOnSlot1;

  private ts_Cvar _frameStyle;
  private ts_Cvar _frameScale;
  private ts_Cvar _frameSize;

  private ts_Cvar _opacity;
  private ts_Cvar _lengthMultiplier;
  private ts_Cvar _barsOnTarget;

  private ts_Cvar _pip;
  private ts_Cvar _emptyPip;
  private ts_Cvar _fontName;
  private ts_Cvar _crosshair;
  private ts_Cvar _crossTop;
  private ts_Cvar _crossBot;
  private ts_Cvar _crossFontName;

  private ts_Cvar _colors[12];

} // class ts_Settings
