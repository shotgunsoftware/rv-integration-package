
module: shotgun_mode {

require shotgun_xmlrpc;
use shotgun_xmlrpc.Value;

use commands;
use rvtypes;
require extra_commands;
require qt;
require app_utils;
require shotgun_api;
require shotgun_info_mode;
require shotgun_stringMap;
require shotgun_fields;
require shotgun_state;
require rvui;
require system;
require glyph;
require math;
require gl;
require io;

EntityFields := shotgun_api.EntityFields;
StringMap := shotgun_stringMap.StringMap;

\: deb(void; string s) { if (false) print("mode: " +s); }

class: ShotgunMinorMode : MinorMode
//
//   Shotgun mode manages the UI of the shotgun integration.  It
//   holds a ShotgunState object which actually talks to shotgun,
//   and uses the shotgun_fields module to manage the information
//   returned by queries to the ShotgunState level.
//
{
    shotgun_state.ShotgunState _shotgunState;

    qt.QPlainTextEdit _textEdit;

    qt.QObject     _shotgunPanel;
    qt.QDockWidget _dockWidget;
    qt.QDockWidget _notesDockWidget;
    qt.QDockWidget _demoDockWidget;
    qt.QWebView    _notesWebView;
    qt.QWebView    _demoWebView;
    qt.QWebView    _helpView;
    bool           _dockWidgetShown;
    bool           _demoDockWidgetShown;

    qt.QPushButton[] _buttons;
    qt.QCheckBox[] _checks;

    bool           _webLoading;
    float          _webProgress;
    int            _currentSource;
    StringMap[]    _postProgLoadInfos;
    bool           _postProgLoadTurnOnWipes;
    string[]       _preProgLoadSources;

    bool[]         _uploadsFinished;
    bool           _uploadInProgress;

    bool _rvVersionGTE3_10_4;
    bool _rvVersionGTE3_10_5;

    //
    //  Preferences
    //

    class: Prefs
    {
        PrefLoadAudioYes      := 0;
        PrefLoadAudioNo       := 1;
        PrefLoadAudioNoPref   := 2;

        PrefLoadRangeFull     := 0;
        PrefLoadRangeNoSlate  := 1;
        PrefLoadRangeCut      := 2;
        PrefLoadRangeNoPref   := 3;

        PrefCompareOpTiled    := 0;
        PrefCompareOpOverWipe := 1;
        PrefCompareOpDiff     := 2;
        PrefCompareOpNoPref   := 3;

        int loadAudio;
        int loadRange;
        int compareOp;

        bool showXmlrpcInFlight;
        bool showPagesInPanel;
        bool trackVersionNotes;
        bool redirectUrls;
        bool drawInfoOnPresentation;

        string loadMedia;
        string serverURL;
        string shotgunUser;
        string shotgunPassword;
        string department;

        string configStyle;

        method: writePrefs (void; )
        {
            deb ("writing prefs shotgunUser %s\n" % shotgunUser);
            writeSetting ("Shotgun", "loadAudio", SettingsValue.Int(loadAudio));
            writeSetting ("Shotgun", "loadMedia2", SettingsValue.String(loadMedia));
            writeSetting ("Shotgun", "loadRange", SettingsValue.Int(loadRange));
            writeSetting ("Shotgun", "compareOp", SettingsValue.Int(compareOp));
            writeSetting ("Shotgun", "showXmlrpcInFlight", SettingsValue.Bool(showXmlrpcInFlight));
            writeSetting ("Shotgun", "redirectUrls", SettingsValue.Bool(redirectUrls));
            writeSetting ("Shotgun", "showPagesInPanel", SettingsValue.Bool(showPagesInPanel));
            writeSetting ("Shotgun", "trackVersionNotes", SettingsValue.Bool(trackVersionNotes));
            writeSetting ("Shotgun", "serverURL", SettingsValue.String(serverURL));
            writeSetting ("Shotgun", "shotgunUser", SettingsValue.String(shotgunUser));
            writeSetting ("Shotgun", "shotgunPassword", SettingsValue.String(shotgunPassword));
            writeSetting ("Shotgun", "department", SettingsValue.String(department));
            writeSetting ("Shotgun", "configStyle", SettingsValue.String(configStyle));
            writeSetting ("Shotgun", "drawInfoOnPresentation", SettingsValue.Bool(drawInfoOnPresentation));
        }

        method: readPrefs (void; )
        {
            let SettingsValue.Int i1 = readSetting ("Shotgun", "loadAudio",
                    SettingsValue.Int(PrefLoadAudioNo));
            loadAudio = i1;

            let SettingsValue.Int i3 = readSetting ("Shotgun", "loadRange",
                    SettingsValue.Int(PrefLoadRangeNoSlate));
            loadRange = i3;

            let SettingsValue.Int i4 = readSetting ("Shotgun", "compareOp",
                    SettingsValue.Int(PrefCompareOpTiled));
            compareOp = i4;

            let SettingsValue.Bool b1 = readSetting ("Shotgun", "showXmlrpcInFlight",
                    SettingsValue.Bool(true));
            showXmlrpcInFlight = b1;

            let SettingsValue.Bool b2 = readSetting ("Shotgun", "showPagesInPanel",
                    SettingsValue.Bool(false));
            // XXX showPagesInPanel = b2;
            showPagesInPanel = false;

            let SettingsValue.Bool b3 = readSetting ("Shotgun", "trackVersionNotes",
                    SettingsValue.Bool(false));
            // XXX trackVersionNotes = b3;
            trackVersionNotes = false;

            let SettingsValue.Bool b4 = readSetting ("Shotgun", "redirectUrls",
                    SettingsValue.Bool(true));
            redirectUrls = b4;

            let SettingsValue.Bool b5 = readSetting ("Shotgun", "drawInfoOnPresentation",
                    SettingsValue.Bool(true));
            drawInfoOnPresentation = b5;

            let SettingsValue.String s1 = readSetting ("Shotgun", "serverURL",
                    SettingsValue.String(""));
            serverURL = s1;

            let SettingsValue.String s2 = readSetting ("Shotgun", "shotgunUser",
                    SettingsValue.String(""));
            shotgunUser = s2;

            let SettingsValue.String s3 = readSetting ("Shotgun", "shotgunPassword",
                    SettingsValue.String(""));
            shotgunPassword = s3;

            let SettingsValue.String s4 = readSetting ("Shotgun", "department",
                    SettingsValue.String("Any"));
            department = s4;

            let SettingsValue.String s5 = readSetting ("Shotgun", "loadMedia2",
                    SettingsValue.String(""));
            loadMedia = s5;

            let style = system.getenv("RV_SHOTGUN_CONFIG_STYLE_FORCE", "");

            if (style == "") 
            {
                let SettingsValue.String s6 = readSetting ("Shotgun", "configStyle",
                        SettingsValue.String(style));
                configStyle = s6;
            }
        }

        method: Prefs (Prefs; )
        {
            this.readPrefs();
        }
    }

    Prefs _prefs;

    //
    //  Methods to set prefs from menu
    //

    method: toggleShowPagesInPanel(void; Event e)
    {
        deb ("toggleShowPagesInPanel currently %s\n" % this._prefs.showPagesInPanel);
        this._prefs.showPagesInPanel = !this._prefs.showPagesInPanel;
        deb ("    now %s\n" % this._prefs.showPagesInPanel);
        _prefs.writePrefs();
    }

    method: toggleTrackVersionNotes(void; Event e)
    {
        deb ("toggleTrackVersionNotes currently %s\n" % this._prefs.trackVersionNotes);
        this._prefs.trackVersionNotes = !this._prefs.trackVersionNotes;
        deb ("    now %s\n" % this._prefs.trackVersionNotes);
        _prefs.writePrefs();
    }

    method: toggleShowInFlight(void; Event e)
    {
        this._prefs.showXmlrpcInFlight = !this._prefs.showXmlrpcInFlight;
        _prefs.writePrefs();
    }

    method: toggleRedirectUrls (void; Event e)
    {
        this._prefs.redirectUrls = !this._prefs.redirectUrls;
        _prefs.writePrefs();
    }

    method: toggleDrawInfoOnPresentation (void; Event e)
    {
        this._prefs.drawInfoOnPresentation = !this._prefs.drawInfoOnPresentation;
        _prefs.writePrefs();
        shotgun_info_mode.theMode()._drawOnPresentation = this._prefs.drawInfoOnPresentation;
    }

    method: toggleLoadAudio(void; Event e)
    {
        if (_prefs.loadAudio == Prefs.PrefLoadAudioYes) 
        {
            _prefs.loadAudio = Prefs.PrefLoadAudioNo;
        }
        else                                      
        {
            _prefs.loadAudio = Prefs.PrefLoadAudioYes;
        }
        _prefs.writePrefs();
    }

    method: setLoadMedia(void; string mediaType, Event e)
    {
        _prefs.loadMedia = mediaType;
        _prefs.writePrefs();
    }

    method: setLoadRange(void; int p, Event e)
    {
        _prefs.loadRange = p;
        _prefs.writePrefs();
    }

    method: setCompareOp(void; int p, Event e)
    {
        _prefs.compareOp = p;
        _prefs.writePrefs();
    }

    //
    //  Methods to export prefs status to menu
    //

    method: showingPagesInPanel (int; )
    {
        deb ("showingPagesInPanel pref is %s\n" % this._prefs.showPagesInPanel);
        if (this._prefs.showPagesInPanel == true) then CheckedMenuState else UncheckedMenuState; 
    }

    method: trackingVersionNotes (int; )
    {
        deb ("trackVersionNotes pref is %s\n" % this._prefs.trackVersionNotes);
        if (this._prefs.trackVersionNotes == true) then CheckedMenuState else UncheckedMenuState; 
    }

    method: showingInFlight (int; )
    {
        deb ("showXmlrpcInFlight pref is %s\n" % this._prefs.showXmlrpcInFlight);
        if (this._prefs.showXmlrpcInFlight == true) then CheckedMenuState else UncheckedMenuState; 
    }

    method: redirectingUrls (int; )
    {
        deb ("redirectUrls pref is %s\n" % this._prefs.redirectUrls);
        if (this._prefs.redirectUrls == true) then CheckedMenuState else UncheckedMenuState; 
    }

    method: drawingInfoOnPresentation (int; )
    {
        deb ("drawInfoOnPresentation pref is %s\n" % this._prefs.drawInfoOnPresentation);
        if (this._prefs.drawInfoOnPresentation == true) then CheckedMenuState else UncheckedMenuState; 
    }

    method: isLoadAudio (int; )
    {
        if (_prefs.loadAudio == Prefs.PrefLoadAudioYes) then CheckedMenuState else UncheckedMenuState; 
    }

    method: isLoadMedia ((int;); string mediaType)
    {
        \: (int;)
        {
            if (this._prefs.loadMedia == mediaType) then CheckedMenuState else UncheckedMenuState; 
        };
    }

    method: isLoadRange ((int;); int p)
    {
        \: (int;)
        {
            if (this._prefs.loadRange == p) then CheckedMenuState else UncheckedMenuState; 
        };
    }

    method: isCompareOp ((int;); int p)
    {
        \: (int;)
        {
            if (this._prefs.compareOp == p) then CheckedMenuState else UncheckedMenuState; 
        };
    }

    //
    //  Methods to set the menuitem active state appropriately.
    //

    \: sourceNodesRendered (string[]; )
    {
        let snr = string[]();

        for_each (mi; metaEvaluate(frame())) if (mi.nodeType == "RVFileSource") snr.push_back (mi.node);

        return snr;
    }

    \: numUniqueSourcesRendered (int; )
    {
        return sourceNodesRendered().size();
    }

    method: singleSourceName(string; )
    {
        let snr = sourceNodesRendered();
        return if (snr.size() == 1) then snr[0] else nil;
    }

    method: enableIfSingleSourceHasInfo (int; )
    {
        let s = singleSourceName();

        if (s neq nil)
        {
            let info = shotgun_fields.infoFromSource (s);

            if (nil neq info) return NeutralMenuState;
        }
        return DisabledMenuState;
    }

    method: enableIfSingleSourceHasEditorialInfo (int; )
    {
        let s = singleSourceName();

        if (s neq nil)
        {
            if (shotgun_fields.sourceHasEditorialInfo (s)) return NeutralMenuState;
        }
        return DisabledMenuState;
    }

    method: enableIfSingleSourceHasField (MenuStateFunc; string field)
    {
        \: (int; )
        {
            let s = singleSourceName();

            if (s neq nil)
            {
                if (shotgun_fields.sourceHasField (s, field)) return NeutralMenuState;
            }
            return DisabledMenuState;
        };
    }

    method: disabledFunc (int;) { return DisabledMenuState; }
    method: neutralFunc (int; ) { return NeutralMenuState; }
    method: checkedFunc (int; ) { return CheckedMenuState; }
    method: uncheckedFunc (int; ) { return UncheckedMenuState; }

    method: doNothing (void; )
    {
        ;
    }
    method: doNothingEvent (void; Event e)
    {
        ;
    }

    /* XXX obsolete
    method: sourcePattern (string; string sub=nil)
    {
        string ret = nil;
        if (sub eq nil) ret = "sourceGroup%06d_source";
        else            ret = "sourceGroup%06d_" + sub;
        deb ("sourcePattern '%s' -> '%s'\n" % (sub, ret));

        return ret;
    }

    method: sourcePropName (string; int sourceNum, string prop, string sub=nil)
    {
        (sourcePattern(sub) % sourceNum) + "." + prop;
    }
    */

    method: toggleInfoWidget(void; Event e)
    {
        shotgun_info_mode.theMode()._drawOnPresentation = this._prefs.drawInfoOnPresentation;
        shotgun_info_mode.theMode().toggle();
    }

    method: togglePanel(void; Event e)
    {
        deb ("toggle panel shown %s\n" % _demoDockWidgetShown);
        if (_demoDockWidgetShown) 
        {
            _demoDockWidget.hide();
            _demoDockWidgetShown = false;
        }
        else 
        {
            _demoDockWidget.show();
            _demoDockWidgetShown = true;
        }
    }

    method: versionIDFromSource (int; string sourceName)
    {
        try
        {
            let info = shotgun_fields.infoFromSource (sourceName);
            string id = info.find("id");
            return if (nil neq id) then int(id) else -1;
        }
        //catch (object obj) { print("ERROR: %s\n" % string(obj)); }
        catch (...) { ; }
        return -1;
    }

    method: versionNameFromSource (string; string sourceName)
    {
        try
        {
            let info = shotgun_fields.infoFromSource (sourceName);
            return info.find("name");
        }
        catch (...) 
        { 
            print ("WARNING: source %s has no version name\n" % sourceName);
        }
        return nil;
    }

    method: updateTrackingInfo (void; string allOrOne, Event e)
    {
        deb ("updateTrackingInfo %s\n" % allOrOne);
        let sources = string[](),
            ids     = int[]();

        if ("all" == allOrOne || numUniqueSourcesRendered() != 1) 
        {
            for_each (s; nodesOfType("RVFileSource"))
            {
                let id = versionIDFromSource (s);
                if (-1 != id) 
                {    
                    ids.push_back(id);
                    sources.push_back (s);
                }
            }
        }
        else 
        {
            let s  = singleSourceName(),
                id = versionIDFromSource (s);
            if (-1 != id) 
            {    
                ids.push_back(id);
                sources.push_back (s);
            }
        }
        shotgun_fields.updateSourceInfoStatus (sources, "updating");
        _shotgunState.collectVersionInfo (ids, shotgun_fields.updateSourceInfo (sources, ));
    }

    method: mediaIsMovie (bool; string m)
    {
        //  XXX need some better way that encompasses mp4, avi, etc.
        let re = regex ("\\.mov$"),
            parts = re.smatch(m);

        if (parts neq nil) return true;

        return false;
    }

    method: mediaTypeFallback (string; string mediaType, StringMap info)
    {
        if (shotgun_fields.mediaTypePathEmpty (mediaType, info))
        {
            let types = shotgun_fields.mediaTypes();
            for_each (t; types)
            {
                if (! shotgun_fields.mediaTypePathEmpty (t, info))
                {
                    mediaType = t;
                    break;
                }
            }
            if (mediaType != _prefs.loadMedia)
            {
                    print ("ERROR: no '%s' media, switching to '%s'\n" % (_prefs.loadMedia, mediaType)); 
            }
            else print ("ERROR: Version has no media!\n"); 
        }
        return mediaType;
    }

    method: swapMediaFromInfo (void; string mediaType, string sourceName)
    {
        deb ("swapMediaFromInfo called, source %s\n" % sourceName);

        int vid = versionIDFromSource (sourceName);
        if (-1 == vid)
        {
            // just skip
            // print ("WARNING: source %d has no version ID\n" % sourceName);
            return;
        }

        string movieProp = "%s.media.movie" % sourceName;
        let oldMedia     = getStringProperty(movieProp);
        StringMap info   = shotgun_fields.infoFromSource (sourceName);
        if (info eq nil) return;

        mediaType        = mediaTypeFallback (mediaType, info);

        string newMedia;
        int frameMin = 0;
        bool hasSlate = true;
        float pa = 0.0;
        try 
        { 
            newMedia = shotgun_fields.mediaTypePath (mediaType, info);
            frameMin = int (info.find ("frameMin"));
            pa = shotgun_fields.mediaTypePixelAspect (mediaType, info);
            hasSlate = shotgun_fields.mediaTypeHasSlate (mediaType, info);
            deb ("    type %s pa %s hasSlate %s media %s\n" % (mediaType, pa, hasSlate, newMedia));
        }
        catch(object obj) 
        {
            print ("ERROR: source %s has versionID, but no '%s' info: %s\n" % 
                    (sourceName, mediaType, obj));
            return;
        }
        //  Actually we still might need to set pixelAspect, etc. so
        //  make the swap even if it looks like there's nothing to do.
        //  if (oldMedia == newMedia) return;

        //  rangeOffset, pixel aspect
        //
        let ro = 0;
        if (frameMin != -int.max && mediaIsMovie (newMedia)) ro = frameMin - (if (hasSlate) then 2 else 1);

        let mode = cacheMode();
        setCacheMode(CacheOff);

        try 
        {
            setStringProperty (sourceName + ".request.stereoViews", string[] {}, true);

            //
            //  We had to swap in this "set the media to empty then use addToSource"
            //  path because in RV prior to 3.10.11, paths added via setSourceMedia were
            //  not processed for %V.  But just discovered that paths added via addToSource
            //  do not trigger a new-source event !  So color processing etc. does not work.
            //  Since the %v thing is fixed, go back to setSourceMedia.
            //
            //setSourceMedia (sname, string[] { });
            //addToSource (sname,  newMedia, "shotgun");
            setSourceMedia (sourceName, string[] { newMedia }, "shotgun");

            _setMediaType (mediaType, sourceName);
            setIntProperty (sourceName + ".group.rangeOffset", int[] {ro});
            let paProp = regex.replace("_source", sourceName, "_transform2D") + ".pixel.aspectRatio";
            deb ("    setting %s to %s\n" % (paProp, float[] {pa}));
            setFloatProperty (paProp, float[] {pa});
        }
        catch (object obj)
        {
            extra_commands.displayFeedback("Can't open '%s'" % newMedia);
            print("ERROR: Can't open '%s'\n" % newMedia);

            try { setSourceMedia (sourceName, oldMedia); }
            catch (...) {;}
        }
        setCacheMode(mode);
        redraw();
    }

    method: swapMedia (void; string allOrOne, string media, Event e)
    {
        deb ("swapMedia\n");
        if ("all" == allOrOne || numUniqueSourcesRendered() != 1) 
        {
            for_each (s; nodesOfType("RVFileSource")) swapMediaFromInfo (media, s);
        }
        else swapMediaFromInfo (media, sourceNodesRendered()[0]);

        deb ("swapMedia done\n");
    }

    method: projectIDFromSource((int,string); string source)
    {
        StringMap info = shotgun_fields.infoFromSource (source);

        let (name, t, id) = shotgun_fields.extractEntityValueParts(info.find("project"));

        return (id, name);
    }

    method: shotIDFromSource((int,string); string source)
    {
        StringMap info = shotgun_fields.infoFromSource (source);

        let (name, t, id) = shotgun_fields.extractEntityValueParts(info.find("shot"));

        return (id, name);
    }

    method: assetIDFromSource((int,string); string source)
    {
        StringMap info = shotgun_fields.infoFromSource (source);

        let (name, t, id) = shotgun_fields.extractEntityValueParts(info.find("asset"));

        return (id, name);
    }

    method: _setMediaType (void; string mt, string sourceName)
    {
        let mtProp = "%s.tracking.mediaType" % sourceName;

        try { newProperty (mtProp, StringType, 1); }
        catch(...) { ; }

        setStringProperty (mtProp, string[]{mt}, true);
    }

    method: _getMediaType (string; string sourceName)
    {
        string mt = nil;

        try { mt = getStringProperty(sourceName + ".tracking.mediaType").front(); }
        catch (...) {;}

        if (mt eq nil) 
        {

            let oldMedia = getStringProperty(sourceName + ".media.movie").front(),
                oldInfo = shotgun_fields.infoFromSource (sourceName);

            mt = shotgun_fields.mediaTypeFromPath (oldMedia, oldInfo);
        }

        return mt;
    }

    method: swapLatestVersionsFromInfos (void; string[] sourceNames, StringMap[] infos)
    {
        deb ("swapLatestVersionsFromInfos sources %s\n" % sourceNames);

        try
        {
            let mode = cacheMode();
            setCacheMode(CacheOff);

            for_index (i; sourceNames)
            {
                let source = sourceNames[i],
                    info   = infos[i];

                //
                //  Don't do anything if we're alread at the latest version.
                //
                if (info.findInt("id") == versionIDFromSource(source)) continue;

                shotgun_fields.updateSourceInfo (string[] {source}, StringMap[] {info});

                swapMediaFromInfo (_getMediaType(source), source);
            }

            setCacheMode(mode);
            redraw();

        }
        catch (object obj)
        {
            print ("ERROR: swapLatestVersionsFromInfos: %s" % string(obj));
        }
    }

    method: trimToLatestInfos (void; 
            StringMap[] infos,
            string department,
            string[] sourceNames,
            StringMap[] collectedInfos)
    {
        deb ("trimToLatestInfos\n");
        try
        {
        StringMap[] latestInfos = StringMap[]();
        deb ("    %s infos, %s collectedInfos, department %s, sourceNames %s\n" %
                (infos.size(), collectedInfos.size(), department, sourceNames));
        for_each (info; infos)
        {
            let sh = info.find("shot"),
                as = info.find("asset"),
                latestID = info.findInt("id"),
                latestDeptID = latestID,
                id = 0,
                deptMatch = false;

            string linkType = nil;

            deb ("    sh %s (sh parts %s) as %s latestID %s\n" % (sh, shotgun_fields.extractEntityValueParts(sh), as, latestID));
            if (sh neq nil)
            {
                deb ("    sh neq nil\n");
                id = shotgun_fields.extractEntityValueParts(sh)._2;
                deb ("    setting linkType\n");
                linkType = "shot";
                deb ("    done setting linkType\n");
            }
            else 
            if (as neq nil)
            {
                deb ("    as neq nil\n");
                id = shotgun_fields.extractEntityValueParts(as)._2;
                linkType = "asset";
            }
            else 
            {
                deb ("continuing\n");
                continue;
            }

            deb ("    linkType %s\n" % linkType);
            StringMap latestInfo = nil, latestDeptInfo = nil;

            for_each (ci; collectedInfos)
            {
                let ciLink = ci.find(linkType);
                if (ciLink eq nil) continue;

                let (_, __, ciLinkID) = shotgun_fields.extractEntityValueParts(ciLink),
                    ciID = ci.findInt("id");
                        
                string dept = "None";
                try { dept = ci.findString("department");} catch(...) {;};

                deb ("        ciLinkID %s ciID %s dept %s\n" % (ciLinkID, ciID, dept));
                if (ciLinkID == id)
                {
                    if (ciID >= latestID)
                    {
                        latestID = ciID;
                        latestInfo = ci;
                    }
                    if (ciID >= latestDeptID && (department == "Any" || department == dept))
                    {
                        latestDeptID = ciID;
                        latestDeptInfo = ci;
                        deptMatch = true;
                    }
                }
            }
            if (nil eq latestInfo) 
            {
                throw "could not find latest info for version %s\n" % info.findString("name");
            }

            latestInfos.push_back(if (deptMatch) then latestDeptInfo else latestInfo);
        }

        swapLatestVersionsFromInfos (sourceNames, latestInfos);
        }
        catch (object obj)
        {
            print ("ERROR: trimToLatestInfos failed: %s\n" % string(obj));
        }
    }

    method: swapLatestVersions (void; string allOrOne, Event e)
    {
        string[] sourceNames; 

        if ("all" == allOrOne) sourceNames = nodesOfType("RVFileSource");
        else                   sourceNames = sourceNodesRendered();

        let infos = StringMap[](),
            sourceNamesWithInfo  = string[]();

        for_each (s; sourceNames)
        {
            let info = shotgun_fields.infoFromSource(s);
            if (info neq nil) 
            {
                infos.push_back(shotgun_fields.infoFromSource(s));
                sourceNamesWithInfo.push_back (s);
            }
        }
        deb ("swapLatestVersions sourceNamesWithInfo %s\n" % sourceNamesWithInfo);

        _shotgunState.collectLatestInfo(infos, _prefs.department,
                trimToLatestInfos (infos, _prefs.department, sourceNamesWithInfo, ));
    }

    method: infoWidgetState (int; )
    {
        shotgun_info_mode.ShotgunInfo si = shotgun_info_mode.theMode();

        if (si._active) then CheckedMenuState else UncheckedMenuState;
    }

    method: panelState (int; )
    {
        //if (_dockWidgetShown) then CheckedMenuState else UncheckedMenuState;
        if (_demoDockWidgetShown) then CheckedMenuState else UncheckedMenuState;
    }

    method: sessionFromEDL (void; string[] sources, string[] media, string[] mediaTypes, int[] ros, float[] pas, int[] ins, int[] outs)
    {
        deb ("sessionFromEDL called media %s ros %s pas %s ins %s outs %s\n" % (media, ros, pas, ins, outs));

        let mode = cacheMode();
        setCacheMode(CacheOff);

        if (!media.empty())
        {
            let args = string[]();
            for_index (i; media)
            {
                args.push_back ("[");
                args.push_back (shotgun_fields.extractLocalPathValue(media[i]));
                args.push_back ("+ro");
                args.push_back ("%s" % ros[i]);
                args.push_back ("+pa");
                args.push_back ("%s" % pas[i]);
                args.push_back ("+in");
                args.push_back ("%s" % ins[i]);
                args.push_back ("+out");
                args.push_back ("%s" % outs[i]);
                args.push_back ("]");
            }
            let evalString = """
                commands.addSources(%s, ""%s);
                """ % (args, if (_rvVersionGTE3_10_5) then ", true" else "");

            deb ("    addSources evalString %s\n" % evalString);
            runtime.eval (evalString);

            deb ("    sources added\n");
        }
        else
        {
            for (int i = 0; i < ins.size()-1; ++i)
            {
                let in  = ins[i],
                    out = outs[i];
                if (in  != int.max-1) setIntProperty (sources[i] + ".cut.in",  int[] {in});
                if (out != int.max-1) setIntProperty (sources[i] + ".cut.out", int[] {out});
            }
        }

        setCacheMode(mode);

        State state = data();
        state.emptySessionStr = "Empty Session";
        redraw();
        deb ("sessionFromEDL done\n");
    }

    method: baseSessionFromInfos (void; string[] sources, int[] rangePrefs, StringMap[] infos)
    {
        deb ("baseSessionFromInfos called rangePrefs %s\n" % rangePrefs);
        let edlMedia      = string[](),
            edlMediaTypes = string[](),
            edlRO         = int[](),
            edlIns        = int[](),
            edlOuts       = int[](),
            edlPAs        = float[]();

        for_index (i; infos)
        {
            // XXX Audio !
            let inf = infos[i],
                frameMin = if (inf neq nil) then inf.findInt("frameMin") else -1,
                frameMax = if (inf neq nil) then inf.findInt("frameMax") else -1;
            int rangePref = _prefs.loadRange;
            string mediaType = nil;

            //  
            //  Only build rangeOffset, media, pixelAspect arrays if
            //  we are actually adding sources.
            //
            deb ("    _prefs.loadMedia %s\n" % _prefs.loadMedia);
            if (rangePrefs eq nil)
            {
                mediaType = mediaTypeFallback (_prefs.loadMedia, inf);

                let newMedia = shotgun_fields.mediaTypePath (mediaType, inf),
                    frameMin = inf.findInt ("frameMin"),
                    pa = shotgun_fields.mediaTypePixelAspect (mediaType, inf),
                    hasSlate = shotgun_fields.mediaTypeHasSlate (mediaType, inf);

                edlMedia.push_back (newMedia);
                edlMediaTypes.push_back (mediaType);
                edlPAs.push_back (pa);

                //  Save mediaType for use by post progressive load code.
                //
                inf.add ("internalMediaType", mediaType);

                deb ("    new media for mediaType %s is %s\n" % (mediaType, newMedia));
                if (mediaIsMovie (newMedia) && frameMin != -int.max)
                {
                    edlRO.push_back (frameMin - (if (hasSlate) then 2 else 1));
                }
                else edlRO.push_back (0);
            }

            //
            //  If we are not adding sources, but just adjusting the
            //  edl, sources we want to change will have something
            //  other than LoadRangeNoPref in the rangePrefs array.
            //
            if (rangePrefs neq nil && rangePrefs[i] != Prefs.PrefLoadRangeNoPref)
            {
                rangePref = rangePrefs[i];
            }

            if (rangePref == Prefs.PrefLoadRangeNoPref)
            {
                deb ("    keeping same edl info\n");

                edlIns.push_back(int.max-1);
                edlOuts.push_back (int.max-1);
            }
            else if (rangePref == Prefs.PrefLoadRangeFull)
            {
                /*
                XXX think this no longer applies, since we can just let the in/out "float"

                if (mediaType eq nil)
                {
                    //  In this case we need to know if the media
                    //  has a slate.  If we don't already know the
                    //  type (because we're adding sources) first
                    //  find the mediaType we previously added.  We
                    //  are counting on the fact that this source
                    //  actually exists.

                    mediaType = _getMediaType (i);
                }
                let hasSlate = shotgun_fields.mediaTypeHasSlate (mediaType, inf);

                deb ("    loading full range, hasSlate %s, mediaType '%s'\n" %
                        (hasSlate, mediaType));
                edlIns.push_back (if (hasSlate && frameMin != -int.max) then frameMin-1 else frameMin);
                edlOuts.push_back (frameMax);
                */
                deb ("    loading full range\n");

                edlIns.push_back  (-int.max);
                edlOuts.push_back ( int.max);
            }
            else if (rangePref == Prefs.PrefLoadRangeNoSlate)
            {
                deb ("    loading full range without slate\n");

                edlIns.push_back(frameMin);
                edlOuts.push_back (frameMax);
            }
            else if (rangePref == Prefs.PrefLoadRangeCut)
            {
                deb ("    loading cut length\n");

                edlIns.push_back(inf.findInt("frameIn"));
                edlOuts.push_back (inf.findInt("frameOut"));
            }
            else print ("ERROR: bad loadRange pref %s\n" % rangePref);

            //  XXX need to add audio
        }
        edlIns.push_back(0);
        edlOuts.push_back(0);

        sessionFromEDL (sources, edlMedia, edlMediaTypes, edlRO, edlPAs, edlIns, edlOuts);
        deb ("baseSessionFromInfos done\n");
    }

    method: sessionFromInfos (void; bool doCompare, bool clearFirst, StringMap[] infos)
    {
        deb ("sessionFromInfo called, %s infos:\n" % infos.size());
        {for_each (i; infos) deb ("    %s\n" % i.toString("        "));}

        try
        {
        if (clearFirst && sources().size() > 0) clearSession();

        baseSessionFromInfos (nil, nil, infos);

        if (1 == optionsPlay() && !isPlaying()) extra_commands.togglePlay();

        if (doCompare)
        {
            let p = _prefs.compareOp;
            deb ("    doCompare mode %s" % p);
            if (p == Prefs.PrefCompareOpTiled) 
            {
                setViewNode("defaultLayout");
                setStringProperty("#RVLayoutGroup.layout.mode", string[]{"packed"});
            }
            else if (p == Prefs.PrefCompareOpOverWipe)
            {
                setViewNode("defaultStack");
                setStringProperty("#RVStack.composite.type", string[]{"over"});
                _postProgLoadTurnOnWipes = true;
            }
            else if (p == Prefs.PrefCompareOpDiff)
            {
                setViewNode("defaultStack");
                setStringProperty("#RVStack.composite.type", string[]{"difference"});
            }
            else print ("ERROR: bad compareOp pref %s\n" % p);
        }

        deb ("    %s infos: \n" % infos.size());
        {for_each (i; infos) deb ("    %s\n" % i.toString("        "));}
        _postProgLoadInfos = infos;
        _preProgLoadSources = nodesOfType("RVFileSource");

        redraw();

        }
        catch (object obj)
        {
            print ("ERROR: sessionFromInfos: %s\n" % string(obj));
        }
    }

    method: sessionFromVersionIDs (void; int[] ids, bool doCompare = false, bool clearFirst = true)
    {
        deb ("shotgun mode sessionFromVersionIDs called\n");
        State state = data();
        if (0 == sources().size()) state.emptySessionStr = "Loading From Shotgun ...";

        if (0 == ids.size()) return;

        _shotgunState.collectVersionInfo(ids, sessionFromInfos(doCompare,clearFirst,));
    }

    method: goToPage (void; string url)
    {
        State state = data();
        try
        {
            openUrl(url);
        }
        catch (exception exc)
        {
            print ("ERROR: can't go to url: EXCEPTION: ");
            print (exc);
            print ("\n");
        }
    }

    /*
    XXX obsolete
    method: sourceNumFromSingleSource (int; )
    {
        let sourceList = sourcesRendered();

        if (numUniqueSourcesRendered() != 1) 
        {
            print ("multiple sources\n");
            return (-1);
        }

        let source = int (regex.smatch("[a-zA-Z]+([0-9]+)", sourceList[0].name).back());

        return source;
    }
    */

    method: goToVersionNotesPage (void; bool force, Event e)
    {
        let src = singleSourceName(),
            vid = versionIDFromSource (src),
            info = shotgun_fields.infoFromSource (src);

        if (-1 != vid)
        {
            string fullName = "";
            try 
            {
                let user  = info.find("user"),
                    name  = shotgun_fields.extractEntityValueParts(user)._0;

                fullName = ""","addressings_to":[{"name":"%s"}]""" % name;
            }
            catch (...) {;}

            string taskName = "";
            try 
            {
                let task  = info.find("task"),
                    name  = shotgun_fields.extractEntityValueParts(task)._0;

                taskName = """,{"name":"%s","type":"Task"}""" % name;
            }
            catch (...) {;}

            string shotName = "";
            try 
            {
                let shot  = info.find("shot"),
                    name  = shotgun_fields.extractEntityValueParts(shot)._0;

                shotName = """,{"name":"%s","type":"Shot"}""" % name;
            }
            catch (...) {;}

            string assetName = "";
            try 
            {
                let asset  = info.find("asset"),
                    name  = shotgun_fields.extractEntityValueParts(asset)._0;

                assetName = """,{"name":"%s","type":"Asset"}""" % name;
            }
            catch (...) {;}

            let (pID, pName) = projectIDFromSource(src),
                vName = versionNameFromSource(src),

                urlString = _prefs.serverURL +
                //"/page/custom_d2_layout?page_id=2580&entity_type=Version&entity_id=%d&show_nav=no" % vid);
                //"/detail/Version/%d?show_nav=no" % vid);
                //"/new/Note?show_nav=no&defaults={%%22project%%22:%%22%s%%22,%%22note_links%%22:[{%%22name%%22:%%22%%22,%22type%22:929}]}
                //"""/new/Note?show_nav=no&project=%s&defaults={"note_links":[{"name":"%s","type":"Version"}]}""" % (pName, vName);
                """/new/Note?show_nav=no&project=%s&defaults={"note_links":[{"name":"%s","type":"Version"}%s%s%s]%s}"""
                        % (pName, vName, taskName, shotName, assetName, fullName);

            if (force || _prefs.showPagesInPanel)
            {
                deb ("********************************** showing panel\n");
                _notesWebView.setZoomFactor(.8);
                qt.QUrl url = qt.QUrl(urlString);
                _notesWebView.load(url);

                _notesDockWidget.show();
            }
            else goToPage (urlString);
        }
    }

    method: goToVersionPage (void; Event e)
    {
        let vid = versionIDFromSource (singleSourceName());
        if (-1 != vid)
        {
            goToPage (_prefs.serverURL + "/detail/Version/%d" % vid);
        }
    }

    method: goToShotPage (void; Event e)
    {
        let source = singleSourceName(),
            vid = versionIDFromSource (source);
        if (-1 == vid) return;

        let (shotID,shotName) = shotIDFromSource(source);
        if (shotID != -1)
        {
            goToPage (_prefs.serverURL + "/detail/Shot/%d" % shotID);
        }
    }

    method: goToAssetPage (void; Event e)
    {
        let source = singleSourceName(),
            vid = versionIDFromSource (source);
        if (-1 == vid) return;

        let (assetID,assetName) = assetIDFromSource(source);
        if (assetID != -1)
        {
            goToPage (_prefs.serverURL + "/detail/Asset/%d" % assetID);
        }
    }

    method: _bake (string; string raw)
    {
        let o = io.osstream();

        for (int i = 0; i < raw.size(); ++i)
        {
            io.print (o, "%02x" % byte(raw[i]));
        }
        return string(o);
    }

    method: copyUrl(void; string which, Event e)
    {
        if (which == "version")
        {
            let source = singleSourceName(),
                vName = versionNameFromSource (source),
                vid = versionIDFromSource (source),
                raw = " -play -l -eval 'shotgun.sessionFromVersionIDs(int[] {%d});'" % vid,
                title = "Version %s" % vName;

            if (_prefs.redirectUrls)
            {
                let url = "%s/rvlink/baked/%s" % (_shotgunState._serverURL, _bake(raw));
                /*
                _textEdit.setPlainText (url);
                _textEdit.selectAll();
                _textEdit.copy();
                print ("Version URL copied: %s\n" % url);
                */
                putUrlOnClipboard (url, title, false);
            }
            else 
            {
                let url = "rvlink://" + raw;
                putUrlOnClipboard (url, title);
            }
        }
        else
        if (which == "session" || which == "session-sync")
        {
            string[] vNames;
            int[] vids;
            string title = "Session with Versions: ";
            for_each (s; nodesOfType("RVFileSource"))
            {
                let vName = versionNameFromSource (s),
                    vid = versionIDFromSource (s);

                if (vid != -1)
                {
                    if (vids.size() != 0) title += ", ";
                    title += vName;
                    vids.push_back(vid);
                }
            }
            if (vids.empty()) return;
            string simpleTitle = "Session with %d Versions" % vids.size();

            string insert =  "-play";
            if (which == "session-sync") 
            {
                insert = "-networkConnect %s %d" % (myNetworkHost(), myNetworkPort());
            }

            let raw = " %s -l -eval 'shotgun.sessionFromVersionIDs(%s);'" % (insert, vids),
                url = "";
            if (_prefs.redirectUrls)
            {
                url = "%s/rvlink/baked/%s" % (_shotgunState._serverURL, _bake(raw));
                /*
                _textEdit.setPlainText (url);
                _textEdit.selectAll();
                _textEdit.copy();
                print ("Session URL copied: %s\n" % url);
                */
                putUrlOnClipboard (url, simpleTitle, false);
            }
            else 
            {
                url = "rvlink://" + raw;
                if (which == "session-sync") simpleTitle = "Sync to Session with %d Versions" % vids.size();
                putUrlOnClipboard (url, simpleTitle);
            }
        }
    }

    method: _sessionFromAllVersions (void; float startTime, bool newSession, StringMap[] infos)
    {
        print ("INFO: retrieved %s Versions in %s seconds\n" % (infos.size(), (theTime() - startTime)));
        if (newSession)
        {
            int[] ids = int[]();
            for_each(info; infos) ids.push_back(int(info.find("id")));

            string url = "rvlink:// -reuse 0 -play -l -eval 'shotgun.sessionFromVersionIDs(%s);'" % ids;
            sessionFromUrl (url);
        }
        else sessionFromInfos (false, true, infos);
    }

    method: allVersions (void; Event e)
    {
        _shotgunState.collectAllVersionInfo(_sessionFromAllVersions(theTime(),true, ));
    }

    method: allEntityVersions (void; string name, string fieldName, string fieldType, bool projConstraint, Event e)
    {
        deb ("allEntityVersions name %s fieldName %s type %s\n" % (name, fieldName, fieldType));
        let source = singleSourceName(),
            info = shotgun_fields.infoFromSource (source);

        if (nil eq info)
        {
            print ("WARNING: source #%s has no tracking info\n" % source);
            return;
        }
        let (_, __, id) = shotgun_fields.extractEntityValueParts (info.find(name)),
            projID = -1;

        if (projConstraint)
        {
            try 
            { 
                let (_, _, id) = shotgun_fields.extractEntityValueParts(info.find("project"));
                projID = id;
            }
            catch (...) {;}
        }

        _shotgunState.collectAllVersionsOfEntity(projID, id, fieldName, fieldType, _sessionFromAllVersions(theTime(),true, ));
    }

    method: isolateShot (void; Event e)
    {
        let vid = versionIDFromSource (singleSourceName());
        if (-1 == vid) return;

        string url = "rvlink:// -reuse 0 -play -l -eval 'shotgun.sessionFromVersionIDs(int[] {%d});'" % vid;
        sessionFromUrl (url);
    }

    method: trimToLatestNeighbors (void; 
            int id,
            int cutOrder,
            string department,
            StringMap[] collectedInfos)
    {
        deb ("trimToLatestNeighbors id %s cutOrder %s number of versions: %s\n" % 
                (id, cutOrder, collectedInfos.size()));

        try
        {

        //  XXX the number of neighbors on either side should be variable.
        //
        int[] cutOrders = { cutOrder-1, cutOrder+1 };
        string[] depts = { "None", "None" };
        int[] ids = int[] { -1, -1 };
        //
        //  XXX crazy that I have to do the below.  if i don't, ids
        //  somehow ignores the initialization above and retains the
        //  values it received in the last call of this method.
        ids[0] = -1;
        ids[1] = -1;

        deb ("    ids %s\n" % ids);
        for_index (i; cutOrders)
        {
            for_each (ci; collectedInfos)
            {
                let ciID = ci.findInt("id"),
                    ciCutOrder = ci.findInt("cutOrder");

                string ciDept = "None";
                try { ciDept = ci.findString("department");} catch(...) {;};

                deb ("    %s: cutOrders[%s] %s ciCutOrder %s ciID %s ids%s\n" % 
                        (i, i, cutOrders[i], ciCutOrder, ciID, ids));
                if (ciCutOrder == cutOrders[i] && (
                    // Nothing else found yet
                    (ids[i] == -1) ||
                    // don't care about department and this one is later
                    (department == "Any" && ciID >= ids[i]) ||
                    // care about department and the one we have is
                    // not right and this one is later.
                    (department != "Any" && depts[i] != department
                    && ciID >= ids[i]) ||
                    // care about department and the one we have is
                    // not right and this one is right dept.
                    (department != "Any" && depts[i] != department && ciDept == department) ||
                    // care about department and the one we have is
                    // right dept and this one is right dept and later.
                    (department != "Any" && depts[i] == department
                    && ciDept == department && ciID >= ids[i])))
                {
                    deb ("    setting %s: id %s\n" % (i, ciID));
                    depts[i] = ciDept;
                    ids[i] = ciID;
                }
            }
        }
        deb ("    ids %s\n" % ids);
        int[] actuals;
        if (ids[0] != -1) actuals.push_back(ids[0]);
        actuals.push_back(id);
        if (ids[1] != -1) actuals.push_back(ids[1]);
        deb ("    actuals %s\n" % actuals);

        string url = "rvlink:// -reuse 0 -play -l -eval 'shotgun.sessionFromVersionIDs(%s);'" % actuals;
        sessionFromUrl (url);
        }
        catch (object obj)
        {
            print ("ERROR: trimToLatestNeighbors failed: %s\n" % string(obj));
        }
    }

    method: isolateShotAndNeighbors (void; Event e)
    {
        deb ("isolateShotAndNeighbors\n");
        let source = singleSourceName(),
            info = shotgun_fields.infoFromSource (source);

        if (nil eq info)
        {
            print ("WARNING: source #%s has no tracking info\n" % source);
            return;
        }
        let cutOrder = info.findInt("cutOrder"),
            id = info.findInt("id"),
            sequenceID = -1,
            (_, __, projectID) = shotgun_fields.extractEntityValueParts (info.find("project")),
            sequenceField = info.find("sequence");
        deb ("    id %s projectID %s\n" % (id, projectID));

        if (sequenceField neq nil) 
            sequenceID = shotgun_fields.extractEntityValueParts (sequenceField)._2;
        deb ("    sequenceID %s\n" % sequenceID);

        _shotgunState.collectNeighborInfos (cutOrder, projectID, sequenceID,
                trimToLatestNeighbors (id, cutOrder, _prefs.department, ));
    }

    method: onlyOneSource (int; )
    {
        let sr = sourcesRendered();

        if (sr.size() == 1) then NeutralMenuState else DisabledMenuState;
    }

    method: changeEdit (void; string allOrOne, int rPref, Event e)
    {
        let sources = nodesOfType("RVFileSource");

        if ("one" == allOrOne)
        {
            if (numUniqueSourcesRendered() != 1) return;
            sources = string[] { singleSourceName() };
        }

        let rangePrefs   = int[](),
            infos        = StringMap[](),
            finalSources = string[]();

        for_each (s; sources)
        {
            let info = shotgun_fields.infoFromSource (s);
            if (nil eq info)
            {
                // for now just skip
                //  XXX we should try to figure out the shotgun
                //  version from the media file name, etc.

                //print ("ERROR: source %d has no version info\n" % i);
                continue;
            }
            rangePrefs.push_back (rPref);
            infos.push_back (info);
            finalSources.push_back (s);
        }
        baseSessionFromInfos (finalSources, rangePrefs, infos);
    }

    method: checkbox (qt.QCheckBox; string name) { /*print ("looking for '%s'\n" % name);*/ _shotgunPanel.findChild(name); }
    method: pushbutton (qt.QPushButton; string name) { /*print ("looking for '%s'\n" % name);*/ _shotgunPanel.findChild(name); }

    method: checkChanged (void; 
                           int index,
                           int value)
    {
        deb ("check changed index %s, val %s\n" % (index, value));
    }

    method: buttonClicked (void; 
                           string name,
                           bool checked)
    {
        deb ("button '%s' pushed.\n" % name);
    }

    method: buttonPressed (void; string name)
    {
        deb ("button pushed %s.\n" % name);
        Event ev;
        if (name == "pbUpdateVersionInfo") 
            updateTrackingInfo("one",ev);
        else 
        if (name == "pbUpdateLatestVersion")
            swapLatestVersions("one",ev);
        else 
        if (name == "pbSwapFrames")
            swapMedia("one", "frames", ev);
        else 
        if (name == "pbSwapMovie")
            swapMedia("one", "movie", ev);
        else 
        if (name == "pbEditFullLength")
            changeEdit("one", Prefs.PrefLoadRangeFull, ev);
        else 
        if (name == "pbEditNoSlate")
            changeEdit("one", Prefs.PrefLoadRangeNoSlate, ev);
        else 
        if (name == "pbEditCutLength")
            changeEdit("one", Prefs.PrefLoadRangeCut, ev);
        else 
        if (name == "pbCopyVersionUrl")
            copyUrl("version",ev);
        else 
        if (name == "pbNewShot")
            isolateShot(ev);
        else 
        if (name == "pbNewShotInContext")
            isolateShotAndNeighbors(ev);
        else 
        if (name == "pbWebAddNote")
            goToVersionNotesPage(true, ev);
        else 
        if (name == "pbWebVersion")
            goToVersionPage(ev);
        else 
        if (name == "pbWebShot")
            goToShotPage(ev);

        //  All Sources
        else 
        if (name == "pbUpdateVersionInfoAll")
            updateTrackingInfo("all",ev);
        else 
        if (name == "pbUpdateLatestVersionAll")
            swapLatestVersions("all",ev);
        else 
        if (name == "pbSwapFramesAll")
            swapMedia("all", "frames", ev);
        else 
        if (name == "pbSwapMovieAll")
            swapMedia("all", "movie", ev);
        else 
        if (name == "pbEditFullLengthAll")
            changeEdit("all", Prefs.PrefLoadRangeFull, ev);
        else 
        if (name == "pbEditNoSlateAll")
            changeEdit("all", Prefs.PrefLoadRangeNoSlate, ev);
        else 
        if (name == "pbEditCutLengthAll")
            changeEdit("all", Prefs.PrefLoadRangeCut, ev);
        else 
        if (name == "pbCopyVersionUrlAll")
            copyUrl("session",ev);
        else 
        if (name == "pbCopySyncSessionUrl")
            copyUrl("session-sync",ev);
    }

    method: buttonPressedFunc ((void;); string name)
    {
        runtime.eval ("""
        FUNCPOINTER = \: (void; )
        {
            deb ("button pushed.\n");
            shotgun.theMode().buttonPressed("%s");
        };
        """ 
        % name, ["commands"]);
        
        //return FUNCPOINTER;
        return nil;
    }

    method: webLoadProgress (void; int percent)
    {
        deb ("webLoadProgress %d\n" % percent);
        if (percent == 100)
        {
            _webLoading = false;
            _webProgress = 0.0;
        }
        else
        {
            _webLoading = true;
            _webProgress = float(percent)/100.0;
            redraw();
        }
    }

    method: _combineMenus (Menu; Menu a, Menu b)
    {
        if (a eq nil) return b;
        if (b eq nil) return a;

        Menu n;
        for_each (i; a) n.push_back(i);
        for_each (i; b) n.push_back(i);
        n;
    }

    method: _buildCurrentSourceMenu (Menu; )
    {
        let m1 = Menu(),
            types = string[]();

        if (shotgun_fields.initialized)
        {
            types = shotgun_fields.mediaTypes();

            if (types.size() > 1)
            {
                m1.push_back (MenuItem {"Swap Media", nil, nil, disabledFunc});
                for_each (t; types)
                {
                    m1.push_back (MenuItem {"    " + t, swapMedia("one", t, ),
                            nil, enableIfSingleSourceHasInfo});
                }
            }
        }

        Menu m2 = Menu {
            {"_", nil},
            {"Edit Clip", nil, nil, disabledFunc},
            {"    Full Length", changeEdit("one", Prefs.PrefLoadRangeFull,),
                    nil, enableIfSingleSourceHasEditorialInfo},
            {"    Full Without Slate", changeEdit("one", Prefs.PrefLoadRangeNoSlate,),
                    nil, enableIfSingleSourceHasEditorialInfo},
            {"    Cut Length", changeEdit("one", Prefs.PrefLoadRangeCut,),
                    nil, enableIfSingleSourceHasEditorialInfo},
            {"_", nil},
            {"Update", nil, nil, disabledFunc},
            {"    Shotgun Info", updateTrackingInfo("one",), nil, enableIfSingleSourceHasInfo},
            {"    To Latest Version", swapLatestVersions("one",), nil, enableIfSingleSourceHasInfo},
            {"_", nil},
            {"New Session", nil, nil, disabledFunc},
            {"    Isolate Version", isolateShot, nil, enableIfSingleSourceHasInfo},
            {"    Isolate Version And Neighbors", isolateShotAndNeighbors, nil, enableIfSingleSourceHasField("cutOrder")},
            {"    All Versions of Shot", allEntityVersions("shot", "entity", "Shot", false,), nil, enableIfSingleSourceHasField("shot")},
            {"    All Versions of Asset", allEntityVersions("asset", "entity", "Asset", false,), nil, enableIfSingleSourceHasField("asset")},
            {"    All Versions of Artist", allEntityVersions("user", "user", "HumanUser", true,), nil, enableIfSingleSourceHasField("user")},
        };

        let m3 = _combineMenus (m1, m2);
    }

    method: _buildAllSourcesMenu (Menu; )
    {
        Menu m1 = Menu {
            {"Update Shotgun Info", updateTrackingInfo("all",), nil, neutralFunc},
            {"Update To Latest Version", swapLatestVersions("all",), nil, neutralFunc},
            //  {"_", nil},
            //  {"Add Audio", doNothingEvent, nil, disabledFunc},
        };

        let m2 = Menu(),
            types = shotgun_fields.mediaTypes();

        if (types.size() > 0)
        {
            m2.push_back (MenuItem {"_", nil});
            for_each (t; types)
            {
                m2.push_back (MenuItem {"Swap in " + t, swapMedia("all", t, ), nil, neutralFunc});
            }
        }

        Menu m4 = Menu {
            {"_", nil},
            {"Edit To Full Length", changeEdit("all", Prefs.PrefLoadRangeFull,), nil, neutralFunc},
            {"Edit To Full Without Slate", changeEdit("all", Prefs.PrefLoadRangeNoSlate,), nil, neutralFunc},
            {"Edit To Cut Length", changeEdit("all", Prefs.PrefLoadRangeCut,), nil, neutralFunc},
            {"_", nil},
            {"Copy Session URL", copyUrl("session",), nil, neutralFunc},
        };

        let m3 = _combineMenus (m1, m2),
            m5 = _combineMenus (m3, m4);
    }

    method: _buildPrefsMenu (Menu; )
    {
        Menu m1 = Menu {
            {"Media Options", doNothingEvent, nil, disabledFunc},
            //  {"With Audio", toggleLoadAudio, nil, isLoadAudio},
        };

        let m2 = Menu(),
            types = string[]();

        if (shotgun_fields.initialized)
        {
            types = shotgun_fields.mediaTypes();
            if (types.size() > 0)
            {
                for_each (t; types)
                {
                    m2.push_back (MenuItem {"Load " + t, setLoadMedia(t,), nil, isLoadMedia(t)});
                }
            }
        }

        Menu m4 = Menu {
            {"_", nil},
            {"Frame Range Options", doNothingEvent, nil, disabledFunc},
            {"Full Length",
                setLoadRange(Prefs.PrefLoadRangeFull,), nil, isLoadRange(Prefs.PrefLoadRangeFull)},
            {"Without Slate",
                setLoadRange(Prefs.PrefLoadRangeNoSlate,), nil, isLoadRange(Prefs.PrefLoadRangeNoSlate)},
            {"Cut Length",
                setLoadRange(Prefs.PrefLoadRangeCut,), nil, isLoadRange(Prefs.PrefLoadRangeCut)},
            {"_", nil},
            {"Compare Options", doNothingEvent, nil, disabledFunc},
            {"Tiled",
                setCompareOp(Prefs.PrefCompareOpTiled,), nil, isCompareOp(Prefs.PrefCompareOpTiled)},
            {"Over, With Wipes",
                setCompareOp(Prefs.PrefCompareOpOverWipe,), nil, isCompareOp(Prefs.PrefCompareOpOverWipe)},
            {"Difference",
                setCompareOp(Prefs.PrefCompareOpDiff,), nil, isCompareOp(Prefs.PrefCompareOpDiff)},
            {"_", nil},
            {"Draw Info Widget on Presentation Device", toggleDrawInfoOnPresentation, nil, drawingInfoOnPresentation},
            {"Set Preferred Department", setDepartment, nil, uncheckedFunc},
            {"Set Shotgun Server", setServerURL, nil, uncheckedFunc},
            {"Set Shotgun Config Style", setShotgunConfigStyle, nil, uncheckedFunc},
            {"Show Feedback", toggleShowInFlight, nil, showingInFlight},
            {"Redirect URLs", toggleRedirectUrls, nil, redirectingUrls},
        };

        let m3 = _combineMenus (m1, m2),
            m5 = _combineMenus (m3, m4);
    }

    method: _buildMenu (Menu; )
    {
        Menu m1 = Menu {
            {"Shotgun Info Widget", toggleInfoWidget, "shift I", infoWidgetState},
            {"_", nil},
            {"Go To Shotgun Page", nil, nil, disabledFunc},
            {"    Add Note ...", goToVersionNotesPage(false,), nil, enableIfSingleSourceHasInfo},
            {"    Version Details ...", goToVersionPage, nil, enableIfSingleSourceHasInfo},
            {"    Shot Details ...", goToShotPage, nil, enableIfSingleSourceHasField("shot")},
            {"    Asset Details ...", goToAssetPage, nil, enableIfSingleSourceHasField("asset")},
            {"_", nil},
            {"Copy Shotgun-Aware RVLINK", nil, nil, disabledFunc},
            {"    Session URL", copyUrl("session",), nil, neutralFunc},
            {"    Current Version URL", copyUrl("version",), nil, enableIfSingleSourceHasInfo},
        };

        let m2 = Menu(),
            types = shotgun_fields.mediaTypes();

        if (types.size() > 0)
        {
            m2.push_back (MenuItem {"_", nil});
            m2.push_back (MenuItem {"Swap Media", nil, nil, disabledFunc});
            for_each (t; types)
            {
                m2.push_back (MenuItem {"    " + t, swapMedia("all", t, ), nil, neutralFunc});
            }
        }

        Menu m4 = Menu {
            {"_", nil},
            {"Edit Clips", nil, nil, disabledFunc},
            {"    Full Length", changeEdit("all", Prefs.PrefLoadRangeFull,), nil, neutralFunc},
            {"    Full Without Slate", changeEdit("all", Prefs.PrefLoadRangeNoSlate,), nil, neutralFunc},
            {"    Cut Length", changeEdit("all", Prefs.PrefLoadRangeCut,), nil, neutralFunc},
            {"_", nil},
            {"Update", nil, nil, disabledFunc},
            {"    Shotgun Info", updateTrackingInfo("all",), nil, neutralFunc},
            {"    To Latest Version", swapLatestVersions("all",), nil, neutralFunc},
            //  {"_", nil},
            //  {"Add Audio", doNothingEvent, nil, disabledFunc},
            {"_", nil},
            {"Current Source Only", _buildCurrentSourceMenu()},
            {"_", nil},
            {"Preferences", _buildPrefsMenu()},
            {"Help ...", _showHelpFile},
        };

        let m3 = _combineMenus (m1, m2),
            m5 = _combineMenus (m3, m4);

        Menu shotgunMenu;
        if (system.getenv("RV_SHOTGUN_TESTING", nil) neq nil)
        {
            shotgunMenu = Menu {{"Shotgun", _combineMenus (
                m5,
                Menu {
                    {"Testing", Menu {
                        {"All Versions", allVersions, nil, neutralFunc},
                        {"All Versions in Project",
                        allEntityVersions("project", "project", "Project", false, ), nil, enableIfSingleSourceHasField("project")},
                        // no worky {"Shotgun Panel", togglePanel, "x", panelState},
                        // no worky {"Shotgun Demo Panel", togglePanel, nil, panelState},
                        // no worky {"Pref: Show Notes Page in Panel", toggleShowPagesInPanel, nil, showingPagesInPanel},
                        // no worky {"Pref: Track Notes Page in Panel", toggleTrackVersionNotes, nil, trackingVersionNotes},
                        {"Pref: Set Shotgun User", setShotgunUser, nil, uncheckedFunc},
                        {"Pref: Set Shotgun Password", setShotgunPassword, nil, uncheckedFunc},
                    }}
                }
            )}};
        }
        else 
        {
            shotgunMenu = Menu {{"Shotgun", m5}};
        }

        return shotgunMenu;
    }

    method: setServerURLValue (void; string v)
    {
        if (v != "")
        {
            if (v == " ") v = "";
            _prefs.serverURL = v;
            _prefs.writePrefs();
            extra_commands.displayFeedback("New Server: " + v);
        }
        redraw();
        _shotgunState._serverURL = _prefs.serverURL;
        _shotgunState.connectToServer();
    }

    method: setServerURL(void; Event e)
    {
        State state = data();
        state.prompt = "Shotgun URL: ";
        state.textFunc = setServerURLValue;
        state.textEntry = true;
        state.textOkWhenEmpty = true;
        state.text = _prefs.serverURL;
        pushEventTable("textentry");
        //rvui.killAllText(e);
        redraw();

        try
        {
            let k = e.key();
            /*if ((k >= '0' && k <= '9') || k == '.')*/ rvui.selfInsert(e);
        }
        catch (...)
        {
            ;// Just ignore non-key events don't selfInsert
        }
    };

    method: setDepartmentValue (void; string v)
    {
        if (v != "")
        {
            _prefs.department = v;
            _prefs.writePrefs();
            extra_commands.displayFeedback("Preferred Department: " + v);
        }
        redraw();
    }

    method: setDepartment(void; Event e)
    {
        State state = data();
        state.prompt = "Preferred Department: ";
        state.textFunc = setDepartmentValue;
        state.textEntry = true;
        state.textOkWhenEmpty = true;
        state.text = _prefs.department;
        pushEventTable("textentry");
        //rvui.killAllText(e);
        redraw();

        try
        {
            let k = e.key();
            /*if ((k >= '0' && k <= '9') || k == '.')*/ rvui.selfInsert(e);
        }
        catch (...)
        {
            ;// Just ignore non-key events don't selfInsert
        }
    };

    method: setShotgunConfigStyleValue (void; string v)
    {
        if (v != "")
        {
            if (v == " ") v = "";
            _prefs.configStyle = v;
            _prefs.writePrefs();
            extra_commands.displayFeedback("Restart RV to use the new style");
        }
        redraw();
    }

    method: setShotgunConfigStyle(void; Event e)
    {
        State state = data();
        state.prompt = "Shotgun Config Style: ";
        state.textFunc = setShotgunConfigStyleValue;
        state.textEntry = true;
        state.textOkWhenEmpty = true;
        try { state.text = _prefs.configStyle; }
        catch (...) { state.text = ""; }
        pushEventTable("textentry");
        //rvui.killAllText(e);
        redraw();

        try
        {
            let k = e.key();
            /*if ((k >= '0' && k <= '9') || k == '.')*/ rvui.selfInsert(e);
        }
        catch (...)
        {
            ;// Just ignore non-key events don't selfInsert
        }
    };


    method: setShotgunUserValue (void; string v)
    {
        if (v != "")
        {
            _prefs.shotgunUser = commands.encodePassword(v);
            _prefs.writePrefs();
            extra_commands.displayFeedback("Shotgun User: " + v);
        }
        redraw();
        _shotgunState._user = _prefs.shotgunUser;
        _shotgunState.connectToServer();
    }

    method: setShotgunUser(void; Event e)
    {
        State state = data();
        state.prompt = "Shotgun User: ";
        state.textFunc = setShotgunUserValue;
        state.textEntry = true;
        state.textOkWhenEmpty = true;
        try { state.text = decodePassword(_prefs.shotgunUser); }
        catch (...) { state.text = ""; }
        redraw();
        pushEventTable("textentry");
        //rvui.killAllText(e);

        try
        {
            let k = e.key();
            /*if ((k >= '0' && k <= '9') || k == '.')*/ rvui.selfInsert(e);
        }
        catch (...)
        {
            ;// Just ignore non-key events don't selfInsert
        }
    };

    method: setShotgunPasswordValue (void; string v)
    {
        if (v != "")
        {
            _prefs.shotgunPassword = commands.encodePassword(v);
            _prefs.writePrefs();
            string stars;
            for (int i = 0; i < v.size(); ++i) stars += "*";
            extra_commands.displayFeedback("Shotgun Password: " + stars);

        }
        redraw();
        _shotgunState._password = _prefs.shotgunPassword;
        _shotgunState.connectToServer();
    }

    method: setShotgunPassword (void; Event e)
    {
        State state = data();
        state.prompt = "Shotgun Password: ";
        state.textFunc = setShotgunPasswordValue;
        state.textEntry = true;
        state.textOkWhenEmpty = true;
        state.text = "";
        pushEventTable("textentry");
        redraw();
        //rvui.killAllText(e);

        try
        {
            let k = e.key();
            /*if ((k >= '0' && k <= '9') || k == '.')*/ rvui.selfInsert(e);
        }
        catch (...)
        {
            ;// Just ignore non-key events don't selfInsert
        }
    }

    method: frameChanged (void; Event event)
    {
        event.reject();
        if (!_prefs.trackVersionNotes) return;

        let sourceList = sourcesRendered();
        if (numUniqueSourcesRendered() != 1) _currentSource = -1;
        else
        {
            let snum  = int(regex.smatch("[a-zA-Z]+([0-9]+)", sourceList[0].name).back());
            if (!isPlaying() && snum != _currentSource)
            {
                if (frame() == outPoint() + 1) return;
                _currentSource = snum;
                if (_prefs.showPagesInPanel && !_notesWebView.modified())
                {
                    goToVersionNotesPage (true, nil);
                }
            }
        }
    }

    method: auxFilePath (string; string file)
    {
        io.path.join(supportPath("shotgun_mode", "shotgun"), file);
    }

    method: _showHelpFile (void; Event event)
    {
        let helpFile = io.path.join(supportPath("shotgun_mode", "shotgun"), "shotgun_help.html");
        if (rvui.globalConfig.os == "WINDOWS")
        {
            let wpath = regex.replace("/", helpFile, "\\\\");
            system.defaultWindowsOpen(wpath);
        }
        else openUrl("file://" + helpFile);
    }

    method: afterProgressiveLoading (void; Event event)
    {
        deb ("afterProgressiveLoading\n");

        event.reject();

        if (_postProgLoadInfos neq nil) 
        {
            deb ("    finding sources\n");
            let postProgLoadSources = string[]();
            let currentSources = nodesOfType("RVFileSource");
            for_each (cs; currentSources)
            {
                let foundIt = false;
                for_each (s; _preProgLoadSources) 
                {
                    if (s == cs) foundIt = true;
                }
                if (!foundIt) 
                {
                    postProgLoadSources.push_back (cs);
                    deb ("added source %s\n" % cs);
                }
            }
            if (postProgLoadSources.size() != _postProgLoadInfos.size())
            {
                print ("ERROR: after progressive loading, number of new sources (%s) != infos (%s)" %
                        (postProgLoadSources.size(), _postProgLoadInfos.size()));
                return;
                
            }

            deb ("    updating info\n");
            shotgun_fields.updateSourceInfo (postProgLoadSources, _postProgLoadInfos);

            deb ("    updating mediaTypes\n");
            for_index (i; _postProgLoadInfos) 
            {
                try 
                { 
                    let t = _postProgLoadInfos[i].find ("internalMediaType", true);

                    _setMediaType (if (t neq nil) then t else _prefs.loadMedia, postProgLoadSources[i]); 
                }
                catch (...) { ; }
            }
            _postProgLoadInfos = nil; 
        }
        if (_postProgLoadTurnOnWipes)
        {
            rvui.toggleWipe();
            _postProgLoadTurnOnWipes = false;
        }
    }

    method: findEntityInURL ((int, string); string url)
    {
        let parts = regex("/([A-Za-z]+)/([0-9]*)$").smatch(url);

        if (parts neq nil && parts.size() == 3)
        {
            if (parts[1] == "Version")   return (int(parts[2]), "Version");
            if (parts[1] == "Shot")      return (int(parts[2]), "Shot");
            if (parts[1] == "Asset")     return (int(parts[2]), "Asset");
            if (parts[1] == "HumanUser") return (int(parts[2]), "User");
            if (parts[1] == "Playlist")  return (int(parts[2]), "Playlist");
            //  XXX should handle  Sequence 
        }
        return (-1, string(nil));
    }

    method: entityVersions (void; int id, string fieldName, string fieldType)
    {
        _shotgunState.collectAllVersionsOfEntity(-1, id, fieldName, fieldType, _sessionFromAllVersions(theTime(),false, ), false);
    }

    method: versionsFromPlaylist (void; int id)
    {
        [string] fieldNames;
        fieldNames = "versions" : fieldNames;

        _shotgunState.requestMultiEntityFields (int[] {id}, "Playlist", fieldNames, sessionFromVersionIDs( , false, true));
    }

    method: urlDoDrop (void; int region, string url)
    {
        let (id, etype) = findEntityInURL (url);

        if (id == -1) return;
        
        if      (etype == "Version") sessionFromVersionIDs (int[] {id}, false, false);
        else if (etype == "Shot")    entityVersions (id, "entity", "Shot");
        else if (etype == "Asset")   entityVersions (id, "entity", "Asset");
        else if (etype == "Playlist") versionsFromPlaylist (id);
        else if (etype == "User")    entityVersions (id, "user",   "HumanUser");
    }

    method: urlDropFunc (((void; int, string), string); string url)
    {
        let (id, etype) = findEntityInURL (url);

        if (id != -1) 
        {
            if (etype == "Version") return (urlDoDrop, "Drop to add %s %s" % (etype, id));
            else                    return (urlDoDrop, "Drop to view versions of %s %s" % (etype, id));
        }
        else          return MinorMode.urlDropFunc (this, url);
    }

    method: ShotgunMinorMode (ShotgunMinorMode;)
    {
        _prefs = Prefs();

        _shotgunState = shotgun_state.ShotgunState(
                _prefs.serverURL,
                _prefs.shotgunUser,
                _prefs.shotgunPassword,
                _prefs.configStyle);

        //
        //  We may have reset the server when trying to connect, so
        //  update the prefs.
        //
        _prefs.serverURL = _shotgunState._serverURL;

        if (shotgun_fields.initialized)
        {
            deb ("mediaTypes: %s\n" % shotgun_fields.mediaTypes());

            if (shotgun_fields.mediaTypes().size() < 1) 
            {
                throw "ERROR: no media types defined in shotgun_fields_config";
            }

            let prefT = _prefs.loadMedia;
            _prefs.loadMedia = "";
            for_each (t; shotgun_fields.mediaTypes()) if (t == prefT) _prefs.loadMedia = t;

            if       ("" == _prefs.loadMedia) _prefs.loadMedia = shotgun_fields.mediaTypes()[0];
        }

        app_utils.bind("key-down--I", toggleInfoWidget, "Toggle Shotgun Info Widget");
        //app_utils.bind("key-down--x", togglePanel, "Toggle Shotgun Demo Panel");

        init("Shotgun",
             nil,
             [("frame-changed", frameChanged, "Update frame"),
              ("play-stop", frameChanged, "Play stopped"),
              ("after-progressive-loading", afterProgressiveLoading, "Update Infos After Load")],
             _buildMenu());

        _drawOnEmpty = true;
        _webLoading = false;
        _webProgress = 0.0;
        _currentSource = -1;

        let mymain = mainWindowWidget();
        _textEdit = qt.QPlainTextEdit("", mymain);
        _textEdit.hide();

        _postProgLoadInfos = nil;
        _postProgLoadTurnOnWipes = false;

        let versionString = system.getenv("TWK_APP_VERSION"),
            parts = versionString.split("."),
            majVersion = int(parts[0]),
            minVersion = int(parts[1]),
            revision   = int(parts[2]);

        _rvVersionGTE3_10_4 = ( (majVersion > 3) ||
                                (majVersion == 3 && minVersion > 10) ||
                                (majVersion == 3 && minVersion == 10 && revision >= 4));
        _rvVersionGTE3_10_5 = (_rvVersionGTE3_10_4 && revision >= 5);

        _uploadsFinished = bool[]();
        _uploadInProgress = false;

        if (false)
        {
        let main = mainWindowWidget();
        _dockWidget = qt.QDockWidget("", main /*, qt.Qt.Drawer*/, /* flags */ 0);
        //  print ("path %s\n" % supportPath("shotgun", "shotgun"));
        _shotgunPanel = qt.loadUIFile(io.path.join(supportPath("shotgun", "shotgun"),
                                            "shotgun_panel.ui"), _dockWidget);
        _dockWidget.setWidget(_shotgunPanel);

        /*
        _dockWidget.setAllowedAreas(qt.Qt.LeftDockWidgetArea |
                                    qt.Qt.RightDockWidgetArea);

        _dockWidget.setFeatures(qt.QDockWidget.DockWidgetClosable |
                                qt.QDockWidget.DockWidgetFloatable |
                                qt.QDockWidget.DockWidgetMovable);
        */

        _checks = qt.QCheckBox[]();
        _buttons = qt.QPushButton[]();

        string[] buttonNames = {
            //  Current Source
            "pbUpdateVersionInfo",
            "pbUpdateLatestVersion",
            "pbSwapFrames",
            "pbSwapMovie",
            "pbEditFullLength",
            "pbEditNoSlate",
            "pbEditCutLength",
            "pbCopyVersionUrl",
            "pbNewShot",
            "pbNewShotInContext",
            "pbWebAddNote",
            "pbWebVersion",
            "pbWebShot",
            //  All Sources
            "pbUpdateVersionInfoAll",
            "pbUpdateLatestVersionAll",
            "pbSwapFramesAll",
            "pbSwapMovieAll",
            "pbEditFullLengthAll",
            "pbEditNoSlateAll",
            "pbEditCutLengthAll",
            "pbCopyVersionUrlAll",
            "pbCopySyncSessionUrl"};

        for_index (i; buttonNames)
        {
            let nm = buttonNames[i];
            _buttons.push_back(pushbutton(nm));
            //  print ("%s\n" % _buttons[i]);
            qt.connect(_buttons[i], qt.QPushButton.pressed, buttonPressedFunc(nm));
        }

        for (int i = 0; i < 1; ++i)
        {
            _checks.push_back(checkbox("checkBox_%s" % i));
            qt.connect(_checks[i], qt.QCheckBox.stateChanged, checkChanged(i,));
        }
        main.addDockWidget(qt.Qt.LeftDockWidgetArea, _dockWidget);
        //_dockWidget.show();
        _dockWidget.hide();
        _dockWidgetShown = false;
        _demoDockWidgetShown = false;
        main.show();
        }

        /*  XXX
        let m = mainWindowWidget(),
            _helpView = qt.QWebView(m),
            helpFile = io.path.join(supportPath("shotgun", "shotgun"), "shotgun_help.html"),
            helpURL = qt.QUrl ("file://" + helpFile);

        _helpView.load(helpURL);

        m.show();
        */

        let tmp = """
        if (false)
        {
        let m = mainWindowWidget();

        _demoDockWidget = qt.QDockWidget("Demo GUI", m, /* flags */ 0);
        let hw = qt.HintWidget((320,400), _demoDockWidget);  // Using HintWidget only way to
                                            // get size to work with some
                                            // widgets: webview is one of those
        _demoWebView = qt.QWebView(hw);

        _demoDockWidget.setWidget(hw);
        hw.setWidget(_demoWebView);
        m.addDockWidget(qt.Qt.LeftDockWidgetArea, _demoDockWidget);

        _demoDockWidget.hide();


        let htmlFile = io.path.join(supportPath("shotgun", "shotgun"), "shotgun_demo.html"),
            url = qt.QUrl ("file://" + htmlFile);

        _demoWebView.load(url);

        javascriptMuExport(_demoWebView.page().mainFrame());
        }
        if (false)
        {
        let m = mainWindowWidget();

        //_notesDockWidget = qt.QDockWidget("notesViewDoc", m, qt.Qt.Drawer);
        _notesDockWidget = qt.QDockWidget("notesViewDoc", m, 0);

        let hw = qt.HintWidget((700,300), _notesDockWidget);  // Using HintWidget only way to
                                            // get size to work with some
                                            // widgets: webview is one of those
        _notesWebView = qt.QWebView(hw);
        _notesWebView.page().setNetworkAccessManager(networkAccessManager());

        _notesDockWidget.setWidget(hw);
        hw.setWidget(_notesWebView);

        /*
        let infile = io.ifstream(auxFilePath("blackui.css")),
            css = io.read_all(infile);
        infile.close();
        print ("css %s\n" % css);

        _notesDockWidget.setStyleSheet(css);
        */
        _notesDockWidget.ensurePolished();
        
        m.addDockWidget(qt.Qt.BottomDockWidgetArea, _notesDockWidget);

        //qt.connect(_notesWebView, qt.QWebView.loadStarted, \: (void;) { print("loadStarted\n"); });
        //qt.connect(_notesWebView, QWebView.loadProgress, \: (void; int p) { print("loadProgress -> %d\n" % p); });
        qt.connect(_notesWebView, qt.QWebView.loadProgress, webLoadProgress);
        //qt.connect(_notesWebView, qt.QWebView.selectionChanged, \: (void;) { print("selectionChanged\n"); });
        //qt.connect(_notesWebView, "titleChanged(const QString&)", \: (void; string title) { print("title is %s\n" % title); });
        //qt.connect(_notesWebView, qt.QWebView.statusBarMessage, \: (void; string title) { print("msg is %s\n" % title); });

        _notesDockWidget.hide();

        m.show();

        javascriptMuExport(_notesWebView.page().mainFrame());
        //  print ("****************** done panel construction\n");
        }
        /*
                qt.QUrl url = qt.QUrl("https://developer.mozilla.org/en");
                //qt.QUrl url = qt.QUrl("https://tweak.shotgunstudio.com");
                //qt.QUrl url = qt.QUrl("http://www.google.com");
                _notesWebView.load(url);
                _notesDockWidget.show();
        */
        """;
    }

    //global int mycount = 0;

    method: render (void; Event event)
    {
        //  _demoDockWidget.clearFocus();
        if (!_prefs.showXmlrpcInFlight) return;

        //  print ("shotgun mode render called\n");
        let (count, startTime) = shotgun_xmlrpc.inFlightStats();
        let frac = 0.0;
        if (count != 0) 
        {
            //  print ("in flight %d, %f\n" % (count, theTime() - startTime));
            //let minutes = (theTime() - startTime) / 5.0,
            let minutes = (theTime() - startTime) / 2.0,
                minFrac = minutes - math.floor(minutes);

            frac = minFrac;

            count = shotgun_api.entitiesSoFar;
            //count = mycount;
            //mycount += 1;
            if (count == 0)
            {
                count = _shotgunState.recordsReturnedLast();
            }
        }
        else if (_webLoading) frac = _webProgress;
        else 
        {
            _shotgunState.resetRecordsReturnedLast();
            //mycount = 0;
            return;
        }

        let radius = 40,
            domain = event.domain(),
            w = domain.x,
            h = domain.y,
            m = margins(),
            x = w - m[1] - radius,
            y = h - m[2] - radius;

        rvui.setupProjection(w, h);

        \: g (void; bool outline)
        {
            gl.glEnable(gl.GL_BLEND);
            gl.glColor(Color(.25, .25, .25, 1));
            glyph.drawCircleFan(0, 0, 0.5, frac, 1.0, .3, outline);
            gl.glColor(Color(.6, .6, .6, 1));
            glyph.drawCircleFan(0, 0, 0.5, 0.0, frac, .3, outline);
            gl.glColor(Color(.25, .25, .25, 1));
            glyph.drawCircleFan(0, 0, 0.3, 0.0, frac, .3, outline);
            gl.glDisable(gl.GL_BLEND);

        }

        glyph.draw (g, x, y, 0.0, radius, false);
        gl.glEnable(gl.GL_LINE_SMOOTH);
        gl.glLineWidth(2.0);
        glyph.draw (g, x, y, 0.0, radius, true);

        if (count != 0)
        {
            let text = string(count),
                tsize = glyph.fitTextInBox(text, 24, 14);
            gltext.size(tsize);
            gltext.color(.9, .9, .9, 1);
            let b = gltext.bounds(text),
                bw = b[0] + b[2],
                bh = b[1] + b[3];
            gltext.writeAt(x-bw/2, y-bh/2, text);
            //  print ("count %d\n" % count);
        }

        redraw();
    }


    //
    //  Upload a jpeg file to a shotgun entity either as an attachement or
    //  as a thumbnail (if arg "thumbnail" is true).  myCallback will be called
    //  as every upload completes.
    //

    method: _uploadJPEGtoEntity (void; 
            string   entityType,
            int      entityID,
            string   fileName,
            string   displayName,
            bool     thumbnail,
            (void;)  myCallback,
            string   eventKey)
    {
        let file  = io.ifstream (fileName, io.stream.In | io.stream.Binary),
            bytes = io.read_all_bytes (file),
            b64   = encoding.to_base64 (bytes),
            url   = "";

        if (thumbnail) url = _shotgunState._serverURL + "/upload/publish_thumbnail";
        else           url = _shotgunState._serverURL + "/upload/upload_file";

        string boundary = "00---------------------------7d03135102b8";

        string contents = "";

        function: param (string; string name, string value)
        {
            "--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % (boundary, name, value);
        };

        contents += param ("entity_type", entityType);
        contents += param ("entity_id",   entityID);
        contents += param ("script_name", "rv");
        contents += param ("script_key",  _shotgunState._scriptKey);

        if (! thumbnail)
        {
            contents += "--%s\r\n" % boundary;
            contents += "Content-Disposition: form-data; "; 
            contents += "name=\"display_name\"\r\n";
            contents += "\r\n%s\r\n" % displayName;
        }

        contents += "--%s\r\n" % boundary;
        contents += "Content-Disposition: form-data; "; 

        if (thumbnail) contents += "name=\"thumb_image\"; ";
        else           contents += "name=\"file\"; ";

        contents += "filename=\"%s\"\r\n" % io.path.basename(fileName);
        contents += "Content-Type: image/jpeg\r\n";
        contents += "Content-Length: %s\r\n\r\n" % string(bytes.size());

        \: byteAppend (void; byte[] b, string s)
        {
            for (int i = 0; i < s.size(); ++i) b.push_back(byte(s[i]));

        }
        \: byteAppend (void; byte[] b, byte[] b2)
        {
            for (int i = 0; i < b2.size(); ++i) b.push_back(b2[i]);
        }

        byte[] finalBytes = byte[]();

        let start = theTime();

        byteAppend (finalBytes, contents);
        byteAppend (finalBytes, bytes);
        byteAppend (finalBytes, "\r\n--%s--\r\n\r\n" % boundary);

        //  print ("assembling byte[] took %s seconds\n" % (theTime() - start));

        [(string,string)] headers;

        headers = ("Connection", "close") : headers;
        headers = ("Content-Type", "multipart/form-data; boundary=%s" % boundary) : headers;
        //  headers = ("Host", "rvdemo.shotgunstudio.com") : headers;
        headers = ("Content-Length", string(finalBytes.size())) : headers;
        headers = ("Accept-Encoding", "identity") : headers;

        function: replyHandler (void; float startTime, (void;) callback, Event event)
        {
            let c = event.contents();

            deb ("reply: %s bytes, %s seconds\n%s\n" % (c.size(), theTime() - startTime, c));

            callback();
        };

        function: authHandler (void; Event event) { print("auth: %s\n" %  event.contents()); }
        function: errorHandler (void; Event event) { print("progress: %s\n" %  event.contents()); }
        function: progressHandler (void; Event event) { print("error: %s\n" %  event.contents()); }

        let replyEvent    = eventKey + "-uploadJPEG--reply",
            authEvent     = eventKey + "-uploadJPEG--auth",
            errorEvent    = eventKey + "-uploadJPEG--error",
            progressEvent = eventKey + "-uploadJPEG--progress";

        app_utils.bind (replyEvent, replyHandler(theTime(),myCallback,));
        app_utils.bind (authEvent, authHandler);
        app_utils.bind (progressEvent, progressHandler);

        let ignoreSslErrors = true;
        deb ("posting %s bytes to '%s'\n" % (finalBytes.size(), url));
        httpPost (url, headers, finalBytes, replyEvent, authEvent, progressEvent, ignoreSslErrors);          
    }

    //
    //  Build a func that takes callbacks from the upload process and updates
    //  list of outstanding upload status.  Sent progress events after each
    //  upload, finished event when they are all complete.
    //

    method: _manageJPEGuploadsFunc ((void;) ; int index, int total, string progressEventName, string finishedEventName)
    {
        \: (void; )
        {
            deb ("_manageJPEGuploadsFunc %s/%s\n" % (index, total));

            this._uploadsFinished[index] = true;

            int done = 0;
            for_each (f; this._uploadsFinished) if (f) ++done;
            let finishedFactor = float(done)/float(this._uploadsFinished.size());

            deb ("    %s complete\n" % finishedFactor);

            if (progressEventName neq nil) sendInternalEvent (progressEventName, string(finishedFactor));

            if (done == this._uploadsFinished.size())
            {
                this._uploadInProgress = false;
                if (finishedEventName neq nil) sendInternalEvent (finishedEventName, "");
            }
        };
    }

    //
    //  Upload the given jpg to the given entity (usually a Version) as a
    //  thumbnail.  send the finished event on completion.
    //

    method: uploadJPEGthumbnail (string; 
            string filePath,
            int    entityID,
            string entityType,
            string finishedEventName)
    {
        let error = "";
        if (_uploadInProgress) return "ERROR: another upload is in progress.";

        _uploadsFinished.resize(1);
        _uploadsFinished[0] = false;

        _uploadJPEGtoEntity (
                entityType,
                entityID,
                filePath,
                io.path.basename(filePath),
                true,
                _manageJPEGuploadsFunc (0, 1, nil, finishedEventName),
                "thumb");

        return error;
    }

    //
    //  Upload the given jpgs to the given entity as attachments.  send the
    //  finished event on completion.  The displayNames are attached to the upload,
    //  the basename of the apppropriate path is used if no displayNames are provided.
    //  progress events are sent after each (asynchronous) upload completes.
    //

    method: uploadJPEGattachments (string; 
            string[] filePaths,
            string[] displayNames,
            int      entityID,
            string   entityType,
            string   progressEventName,
            string   finishedEventName)
    {
        let error = "";
        if (_uploadInProgress) return "ERROR: another upload is in progress.";

        _uploadsFinished.resize(filePaths.size());
        for_index (i; _uploadsFinished) _uploadsFinished[i] = false;
        _uploadsFinished[0] = false;

        for_index (i; filePaths)
        {
            _uploadJPEGtoEntity (
                    entityType,
                    entityID,
                    filePaths[i],
                    if (displayNames neq nil) then displayNames[i] else io.path.basename(filePaths[i]),
                    false,
                    _manageJPEGuploadsFunc (i, filePaths.size(), progressEventName, finishedEventName),
                    "attach_" + string(i));
        }

        return error;
    }

    /*
    method: render (void; Event event)
    {
        if (_currentMatte eq nil) return;

        \: sort (Vec2[]; Vec2[] array)
        {
            // only handles flipping not flopping right now
            if array[0].y < array[2].y
                then Vec2[] { array[3], array[2], array[1], array[0] }
                else array;
        }


        State state = data();
        setupProjection(event.domain().x, event.domain().y);

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        gltext.size(20.0);
        gltext.color(Color(1,1,1,1) * .5);
    
        let {_, l, r, b, t, text} = _currentMatte;

        let bounds = gltext.bounds(text),
            th     = bounds[1] + bounds[3];

        Color c = state.config.matteColor;
        c.w = state.matteOpacity;

        glColor(c);
        
        for_each (ri; sourcesRendered())
        {
            let g = sort(sourceGeometry(ri.name)),
                w = g[2].x - g[0].x,
                h = g[2].y - g[0].y,
                a = w / h,
                x0 = g[0].x + l * w,
                x1 = g[2].x - r * w,
                y0 = g[0].y + t * h,
                y1 = g[2].y - b * h;

            glBegin(GL_QUADS);

            //  Top 
            glVertex(g[0]);
            glVertex(g[1]);
            glVertex(g[1].x, y0);
            glVertex(g[0].x, y0);

            //  Bottom
            glVertex(g[3].x, y1);
            glVertex(g[2].x, y1);
            glVertex(g[2]);
            glVertex(g[3]);

            //  Left
            glVertex(g[0].x, y0);
            glVertex(x0, y0);
            glVertex(x0, y1);
            glVertex(g[0].x, y1);

            //  Right
            glVertex(g[1].x, y0);
            glVertex(x1, y0);
            glVertex(x1, y1);
            glVertex(g[1].x, y1);

            glEnd();

            gltext.writeAt(x0, y1 - th - 5, text);
        }

        glDisable(GL_BLEND);
    }
    */
}

\: createMode (Mode;)
{
    deb ("creating ShotgunMinorMode\n");
    return ShotgunMinorMode();
}

\: theMode (ShotgunMinorMode; )
{
    ShotgunMinorMode m = rvui.minorModeFromName("Shotgun");

    return m;
}

\: sessionFromVersionIDs(string; int[] ids, string flags="")
{
    try
    {
        ShotgunMinorMode m = theMode();
        rvui.clearEverything();
        m.sessionFromVersionIDs (ids);
    }
    catch (object obj)
    {
        print ("ERROR: sessionFromVersionIDs failed: %s" % string(obj));
    }

    return ("noprint");
}

\: compareFromVersionIDs(string; int[] ids, string flags="")
{
    try
    {
        ShotgunMinorMode m = theMode();
        rvui.clearEverything();
        m.sessionFromVersionIDs (ids, true);
    }
    catch (object obj)
    {
        print ("ERROR: compareFromVersionIDs failed: %s" % string(obj));
    }
    return ("noprint");
}

\: _runRVIOcleanupFunc ((void; ); string eventName)
{
    \: (void; )
    {
        require export_utils;
        require external_qprocess;

        let errors = "";

        //  caller must remove any temp session data
        //
        //  export_utils.removeTempSession();

        State state = data();
        if (state.externalProcess neq nil) 
        {
            external_qprocess.ExternalQProcess qp = state.externalProcess;
            if (qp._errors != "") errors = "ERROR: " + qp._errors;
        }

        sendInternalEvent (eventName, errors);
        state.unregisterQuitMessage ("runRVIO");
    };
}

//
//  Start an external process to run rvio_hw false) with the given args.
//  Send event finishEventName when process is complete, with event
//  contents indicating any error (contents are empty if there was
//  no error).
//
//  NOTE: output move/sequence is assumed to be in "args", and this code
//  does not clean it up or do anything with it.  Likewise the rvio input
//  file, presumably a session file, is not managed by this code.
//

\: runRVIO (string; string[] args, string finishEventName) 
{

    State state = data();

    if (state.externalProcess neq nil)
    {
        int choice = alertPanel (
                true, // associated panel (sheet on OSX)
                WarningAlert,
                "WARNING", "Another process is still running",
                "OK", nil, nil);
        return;
    }
    let error = "";

    try
    {
        require export_utils;
        require rvui;

        state.externalProcess = export_utils.rvio ("Export Movie", args, _runRVIOcleanupFunc(finishEventName));
        rvui.toggleProcessInfo();
        redraw();
        state.registerQuitMessage ("runRVIO", "There is an 'Export Movie' process running.");
    }
    catch (object obj)
    {
        error = string(obj);
    }
    catch (...)
    {
        error = "unknown error";
    }
    if (error != "")
    {
        int choice = alertPanel (
                true, // associated panel (sheet on OSX)
                ErrorAlert,
                "ERROR", "Unable to call RVIO: %s" % error,
                "OK", nil, nil);
    }
    return error;
}

}
shotgun := shotgun_mode;
