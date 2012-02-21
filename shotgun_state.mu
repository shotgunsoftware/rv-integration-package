
module: shotgun_state {

require rvtypes;
require app_utils;
use commands;
use shotgun_xmlrpc;
use Value;
require shotgun_api;
require shotgun_stringMap;
require shotgun_fields;

StringMap := shotgun_stringMap.StringMap;
EntityFields := shotgun_api.EntityFields;

\: deb(void; string s) { if (false) print("state: " + s); }

function: lookupServer((string, string); string defaultURL)
{
    string serverMap = system.getenv ("RV_SHOTGUN_SERVER_MAP_FORCE", nil);
    try 
    {
        if (serverMap eq nil) serverMap = shotgun_fields.serverMap();
    }
    catch (object obj)
    {
        print ("ERROR: (shotgun) config module serverMap function: %s\n" % string(obj));
    }

    (string, string) nilTuple;
    nilTuple._0 = nil;
    nilTuple._1 = nil;
    if (serverMap eq nil)
    {
        print ("ERROR: (shotgun) No server map set in config module\n");
        return nilTuple;
    }
    let parts = serverMap.split(" ");

    if (parts.size() == 0 || parts.size() % 2 != 0)
    {
        print ("ERROR: (shotgun) bad SERVER_MAP: '%s'\n" % serverMap);
        return nilTuple;
    }
    if (defaultURL eq nil || defaultURL == "") defaultURL = parts[0];

    for (int i = 0; i < parts.size()-1; i += 2)
    {
        if (parts[i] == defaultURL) return (defaultURL, parts[i+1]);
    }

    return (parts[0], parts[1]);
}

class: ShotgunState
{
    string                    _serverURL;
    string                    _scriptKey;
    shotgun_api.ShotgunServer _shotgunServer;
    bool                      _authenticated;
    int                       _recordsReturnedLast;

    //
    //  These are encrypted.  To decrypt: plainTextPassword = commands.decodePassword(_password);
    //
    string                    _user;
    string                    _password;

    method: ShotgunState (ShotgunState; string url, string user, string password, string configStyle)
    {
        _serverURL = url;
        _shotgunServer = nil;
        _scriptKey = nil;
        _user = user;
        _password = password;
        _authenticated = false;
        _recordsReturnedLast = 0;

        let ok = true;

        try 
        {
            shotgun_fields.init(configStyle);
        }
        catch (object obj)
        {
            print ("ERROR: (shotgun) %s\n" % string(obj));
            print ("ERROR: Please set the configStyle preference or install a custom config module and restart RV.\n");
            ok = false;
        }

        // defer connecting to server until we know which server launched us
        // if (ok) this.connectToServer();
    }

    method: recordsReturnedLast(int;)
    {
        return _recordsReturnedLast;
    }

    method: resetRecordsReturnedLast(void; )
    {
        _recordsReturnedLast = 0;
    }

    method: authenticate(void; )
    {
        _authenticated = false;

        string realUser = commands.decodePassword(_user);
        string realPass = commands.decodePassword(_password);

        let text   = "ignore_browser_check=1&user%%5Blogin%%5D=%s&user%%5Bpassword%%5D=%s&commit=Sign+In" 
                    % (realUser, realPass),
            hash   = string.hash(text + string(theTime())),
            revent = "auth-%s-return" % hash,
            aevent = "auth-%s-authenticate" % hash,
            eevent = "auth-%s-error" % hash;
        
        \: returnFunc (void; Event event)
        {
            deb ("authentication normal return: (%s chars)\n" % event.contents().size());
            deb ("    contents: %s\n" % event.contents());
            for_each (event; [revent, aevent, eevent]) app_utils.unbind(event);
            if (regex.match("You are being", event.contents()))
            {
                this._authenticated = true;
                print ("INFO: Logged in to Shotgun as '%s'\n" % realUser);
            }
            else print ("INFO: Shotgun login failed\n");
        }

        \: errorFunc (void; Event event)
        {
            deb ("authentication error return: %s\n" % event.contents());
            for_each (event; [revent, aevent, eevent]) app_utils.unbind(event);
        }

        \: authenticateFunc (void; Event event)
        {
            deb ("authentication authenticate return: %s\n" % event.contents());
            for_each (event; [revent, aevent, eevent]) app_utils.unbind(event);
        }

        app_utils.bind(revent, returnFunc);
        app_utils.bind(aevent, authenticateFunc);
        app_utils.bind(eevent, errorFunc);

        httpPost(_serverURL + "/user/login",
                [   //  HTTP Headers
                    ("Content-Type", "application/x-www-form-urlencoded"),
                    ("Referer", "%s/user/login?ignore_browser_check=1" % _serverURL),
                    ("Accept", "application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5"),
                    ("Origin", _serverURL),
                    ("Accept-Language", "en-us"),
                    ("Accept-Encoding", "gzip, deflate"),
                    ("Content-Length", string(text.size())),
                    ("Connection", "keep-alive"),
                    ("Proxy-Connection", "keep-alive"),
                ],
                text,
                revent, aevent, eevent, true /* ignoreSslErrors */);
    }


    method: connectToServer(void; string serverUrl="")
    {
        try 
        {

            string lookup;
            if (serverUrl == "")
            {
                // if we've already connected, then there is nothing to do
                if (_shotgunServer neq nil) return;
                lookup = _serverURL;
            }
            else
                lookup = serverUrl;
            let (url, scriptKey) = lookupServer (lookup);

            /*
             * default url to connect to becomes last server passed in.
             * this doesn't work great for sessions where entities come from different
             * servers, but support for that is in the future
             */
            _serverURL = url;
            _scriptKey = scriptKey;
            if (url eq nil) throw exception ("ShotgunState: cannot connect to nil url");

            print ("INFO: using shotgun server '%s'\n" % url);

            _shotgunServer = shotgun_api.ShotgunServer (
                    _serverURL + "/api3_preview/",
                    "rv",
                    scriptKey);
        }
        catch (exception exc)
        {
            print("ERROR: Failed to connect to Shotgun server: %s\n" %exc);
        }
        try
        {
            //deb ("    user     '%s' -> '%s'\n" % (_user, commands.decodePassword(_user)));
            //deb ("    password '%s' -> '%s'\n" % (_password, commands.decodePassword(_password)));
            ;

            //  XXX turn this back on when we actually do
            //  usr-authentication.

            //  authenticate();
        }
        catch (object obj)
        {
            print ("INFO: Shotgun login failed\n");
        }
        
    }

    method: printValuesMethod (void; EntityFields fields)
    {
        let types = fields.extractStringField("type"),
            ids = fields.extractIntField("id"),
            codes = fields.extractStringField("code"),
            descriptions = fields.extractStringField("description");

        print ("printValues called with %d results\n" % codes.size());

        for_index (i; codes)
        {
            print("%s '%s' id=%d '%s'\n" % (
                    types[i]._1,
                    codes[i]._1,
                    codes[i]._0,
                    descriptions[i]._1));
        }
    }

    method: _findNextEntity ((string, int[]); StringMap[] infos, string[] requestedEntities)
    {
        deb ("ShotgunState _findNextEntity called\n");
        string nextEntity;
        int[] newTargetIDs;
        do {
            nextEntity = nil;
            newTargetIDs.clear();
            for_each (fd; shotgun_fields.fields)
            {
                if (!fd.compute)
                {
                    if (infos[0].find(fd.name) eq nil) 
                    {
                        bool alreadyRequested = false;
                        for_each (e; requestedEntities) 
                        {
                            if (e == fd.entityType) alreadyRequested = true;
                        }
                        if (!alreadyRequested)
                        {
                            nextEntity = fd.entityType;
                            break;
                        }
                    }
                }
            }

            deb ("    nextEntity candidate %s\n" % nextEntity);
            if (nextEntity neq nil)
            {
                bool foundAtLeastOne = false;
                for_each (info; infos)
                {
                    newTargetIDs.push_back(-1);
                    for_each (k; info.keys()) 
                    {
                        //  deb ("    checking field %s: %s\n" % (k, info.find(k)));
                        if (shotgun_fields.fieldTypeMap.find(k) == "entity" &&
                            shotgun_fields.prettyNameMap.find(k) == nextEntity &&
                            info.find(k) neq nil)
                        {
                            //  deb ("    extracting %s from %s\n" % (nextEntity, info.find(k)));
                            let (_, _, id) = shotgun_fields.extractEntityValueParts (info.find(k));
                            //
                            //  Note we push an id onto newTargetIDs
                            //  even if it's -1, since we must have
                            //  one ID per info.
                            //
                            newTargetIDs.back() = id;
                            if (-1 != id) foundAtLeastOne = true;
                        }
                    }
                }
                if (!foundAtLeastOne)
                {
                    requestedEntities.push_back (nextEntity);
                    nextEntity = nil;
                }
            }
            else break;

        } while (nextEntity eq nil);
        deb ("    nextEntity %s newTargetIDs %s\n" % (nextEntity, newTargetIDs));

        return (nextEntity, newTargetIDs);
    }

    documentation: """
    This is the function that processes the result of the general
    shotgun queries used to retrieve field values from shotgun.
    After doing any required intermediate processing on the
    retrieved values, it checks to see if there are missing fields
    on entities that have not yet been queried.  If so, it sets up
    another query for that entity type and sends it off.  If not, 
    it calls the supplied finishing function "afterFunc"."""


    method: _processInfoFields (void; 
            int[] targetIDs,
            string targetEntity,
            string[] requestedEntities,
            StringMap[] infos,
            (void; StringMap[]) afterFunc,
            bool idsOnly,
            EntityFields fields)
    {
        deb ("ShotgunState _processInfoFields called\n");
        deb ("    %s infos\n" % infos.size());
        deb ("    %s fields\n" % fields.size());
        deb ("    targetIDs %s\n" % targetIDs);
        deb ("    targetEntity %s\n" % targetEntity);
        deb ("    idsOnly %s\n" % idsOnly);
        _recordsReturnedLast = fields.size();
        \: indiciesFromTargetID (int[]; int id)
        {
            int[] indices;
            for_index (i; targetIDs) if (targetIDs[i] == id) indices.push_back(i);
            return indices;
        }

        try
        {

        for_each (fd; shotgun_fields.fields)
        {
            if (fd.entityType != targetEntity || fd.compute) continue;

            //  deb ("    extracting values for %s\n" % fd.fieldName);
            let fieldValues = fields.extractField(fd.fieldName);
            //  deb ("    extracting values for %s: %s\n" % (fd.fieldName, fieldValues));

            if (0 == fieldValues.size()) continue;

            for_index (i; fieldValues)
            {
                let (id, v) = fieldValues[i],
                    indicies = indiciesFromTargetID(id);

                //  deb ("    indicies %s v %s\n" % (indicies, v));
                if (0 == indicies.size()) 
                {
                    if (targetEntity == "Version")
                    {
                        //  deb ("    new targetID %s\n" % id);
                        indicies.push_back(targetIDs.size());
                        targetIDs.push_back(id);
                        infos.push_back(shotgun_fields.freshInfo());
                    }
                }
                for_each (index; indicies)
                {
                    //
                    //  XXX cutOrder is special
                    //

                    let vs = shotgun_fields.prettyPrintValue(v);
                    //  deb ("    vs %s\n" % vs);
                    if (vs != "nil")
                    {
                        if (fd.name == "cutOrder") vs = string(shotgun_fields.actualCutOrder(vs));
                        infos[index].add(fd.name, vs);
                    }
                }
            }
            //  deb ("    looping\n");
        }
        //
        //  If idsOnly, we only wanted the version IDs, which we got
        //  in the first call, so go straight to "afterfunc"
        //
        if (idsOnly)
        {
            afterFunc(infos);
            return;
        }

        //
        //  Call compute to possibly compute shotgun fields that
        //  cannot be retrieved.
        //
        deb ("    computing\n");
        for_each (i; infos) shotgun_fields.compute(i);

        deb ("    %s infos:\n" % infos.size());
        if (infos.size() < 10)
        {
            for_each (info; infos) deb ("        info: %s\n" % info.toString("            "));
        }
        
        requestedEntities.push_back(targetEntity);
        let (nextEntity, newTargetIDs) = _findNextEntity (infos, requestedEntities);
        if (nextEntity eq nil)
        {
            for_each (i; infos) 
            {
                i.add ("shotgunURL", _serverURL);
                shotgun_fields.compute(i, false);
            }
            deb ("    nextEntity is nil, so calling afterFunc\n");
            afterFunc(infos);
            return;
        }
        else 
        {
            deb ("    nextEntity is %s, requesting info\n" % nextEntity);
            _requestInfo (newTargetIDs, nextEntity, requestedEntities, infos, afterFunc, "");
        }
        }
        catch (exception exc)
        {
            print("ERROR: _processInfoFields: %s\n" % exc);
        }
    }

    method: _updateEmptySessionStr (void; string s)
    {
        rvtypes.State state = data();

        if (regex.match("Loading From Shotgun.*", state.emptySessionStr))
        {
            state.emptySessionStr = "Loading From Shotgun (%s) ..." % s;
        }
    }

    method: unpackMultiEntityField (void; (void; int[]) afterFunc, EntityFields fields)
    {
        deb ("unpackMultiEntityField fields\n");
        deb ("     fields %s\n" % fields);
        deb ("     entities.size %s\n" % fields._entities.size());

        if (fields._entities.size() != 1) return;
        if (fields._entities[0].size() != 3) return;

        let Value.Array array = fields._entities[0][1]._1,
            ids = int[]();

        for_each (v; array)
        {
            let Value.Struct s = v;
            let [_, _, (_, Int id)] = s;
            ids.push_back(id);
        }
        deb ("    ids %s\n" % ids);

        afterFunc(ids);
    }

    method: requestMultiEntityFields (void; 
            int[] targetIDs,
            string targetEntity,
            [string] requestedFields,
            (void; int[]) afterFunc)
    {
        deb ("ShotgunState _requestFields called\n");
        deb ("    targetIDs %s\n" % targetIDs);
        deb ("    targetEntity %s\n" % targetEntity);

        _updateEmptySessionStr (targetEntity);

        int validIDCount = 0;
        [Value] conditionList;
        for_each (id; targetIDs) 
        {
            if (-1 != id)
            {
                ++validIDCount;
                Value singleCondition = Struct ([
                    ("path", String("id")),
                    ("relation", String("is")),
                    ("values", Array([ Int(id) ]))
                ]);

                conditionList = singleCondition : conditionList;
            }
        }
        Value condition = Array(conditionList);

        deb ("    %s valid IDs for query condition\n" % validIDCount);
        deb ("    requestedFields %s\n" % requestedFields);

        _shotgunServer.find(
            targetEntity,
            requestedFields,
            unpackMultiEntityField (afterFunc, ),
            Struct( [
                ("logical_operator", String("or")),
                ("conditions", condition)
            ]));
    }

    method: _requestInfo (void; 
            int[] targetIDs,
            string targetEntity,
            string[] requestedEntities,
            StringMap[] infos,
            (void; StringMap[]) afterFunc,
            string serverUrl)
    {
        deb ("ShotgunState _requestInfo called\n");
        deb ("    targetIDs %s\n" % targetIDs);
        deb ("    targetEntity %s\n" % targetEntity);
        deb ("    serverUrl %s\n" % serverUrl);
        deb ("    _serverURL %s\n" % _serverURL);

        // if we are trying to talk to a different shotgun server than the default
        if (serverUrl != _serverURL)
            connectToServer(serverUrl);

        _updateEmptySessionStr (targetEntity);

        int validIDCount = 0;
        [Value] conditionList;
        for_each (id; targetIDs) 
        {
            if (-1 != id)
            {
                ++validIDCount;
                Value singleCondition = Struct ([
                    ("path", String("id")),
                    ("relation", String("is")),
                    ("values", Array([ Int(id) ]))
                ]);

                conditionList = singleCondition : conditionList;
            }
        }
        Value condition = Array(conditionList);

        deb ("    %s valid IDs for query condition\n" % validIDCount);
        deb ("    fieldListByEntity %s\n" % shotgun_fields.fieldListByEntityType(targetEntity));

        _shotgunServer.find(
            targetEntity,
            shotgun_fields.fieldListByEntityType(targetEntity),
            _processInfoFields (targetIDs,targetEntity,requestedEntities,infos,afterFunc,false, ),
            Struct( [
                ("logical_operator", String("or")),
                ("conditions", condition)
            ]));
    }

    method: collectVersionInfo (void; int[] ids, (void; StringMap[]) afterFunc, string serverURL="")
    {
        deb ("ShotgunState collectVersionInfo called\n");
        deb ("    ids %s\n" % ids);
        deb ("    serverURL %s\n" % serverURL);
        if (0 == ids.size()) return;

        StringMap[] infos;
        for_each (id; ids) infos.push_back(shotgun_fields.freshInfo());
        deb ("    info[0] %s\n" % infos[0].toString("        "));

        _requestInfo (ids, "Version", string[](), infos, afterFunc, serverURL);
    }

    method: collectAllVersionInfo (void; (void; StringMap[]) afterFunc)
    {
        _shotgunServer.find(
            "Version",
            shotgun_fields.fieldListByEntityType("Version"),
            _processInfoFields (int[](),"Version",string[](),StringMap[](), afterFunc, true, ),
            Struct( [
                ("logical_operator", String("or")),
                ("conditions", EmptyArray)
            ]));
    }

    method: collectAllVersionsOfEntity (void; int projID, int id, string name, string eType, (void; StringMap[]) afterFunc, bool idsOnly=true)
    {
        [Value] conditions;

        deb ("collectAllVersionsOfEntity projID %s id %s name %s eType %s\n" % (projID, id, name, eType));

        Value entStruct = Struct ([
            ("id", Int(id)),
            ("type", String(eType))
        ]);
        Value entCondition = Struct ([
            ("path", String(name)),
            ("relation", String("is")),
            ("values", Array([ entStruct ]))
        ]);
        conditions = entCondition : conditions;

        if (projID != -1)
        {
            Value projStruct = Struct ([
                ("id", Int(projID)),
                ("type", String("Project"))
            ]);
            Value projCondition = Struct ([
                ("path", String("project")),
                ("relation", String("is")),
                ("values", Array([ projStruct ]))
            ]);

            conditions = projCondition : conditions;
        }

        _shotgunServer.find(
            "Version",
            shotgun_fields.fieldListByEntityType("Version"),
            _processInfoFields (int[](),"Version",string[](),StringMap[](), afterFunc, idsOnly, ),
            Struct( [
                ("logical_operator", String("and")),
                ("conditions", Array(conditions))
            ]));
    }

    method: collectLatestInfo (void; StringMap[] infos, string department, (void; StringMap[]) afterFunc)
    {
        [Value] conditionList;
        for_each (info; infos) 
        {
            let sh = info.find("shot");
            let as = info.find("asset");
            if (sh neq nil)
            {
                let (name, t, id) = shotgun_fields.extractEntityValueParts(sh);

                Value shotStruct = Struct ([
                    ("id", Int(id)),
                    ("type", String("Shot"))
                ]);
                Value singleVersionCondition = Struct ([
                    ("path", String("entity")),
                    ("relation", String("is")),
                    ("values", Array([ shotStruct ]))
                ]);

                conditionList = singleVersionCondition : conditionList;
            }
            else
            if (as neq nil)
            {
                let (name, t, id) = shotgun_fields.extractEntityValueParts(as);

                Value assetStruct = Struct ([
                    ("id", Int(id)),
                    ("type", String("Asset"))
                ]);
                Value singleVersionCondition = Struct ([
                    ("path", String("entity")),
                    ("relation", String("is")),
                    ("values", Array([ assetStruct ]))
                ]);

                conditionList = singleVersionCondition : conditionList;
            }
            else throw exception ("ShotgunState: version is of neither asset nor shot");
        }
        Value condition = Array(conditionList);

        _shotgunServer.find(
            "Version",
            shotgun_fields.fieldListByEntityType("Version"),
            _processInfoFields (int[](),"Version",string[](),StringMap[](), afterFunc, false, ),
            Struct( [
                ("logical_operator", String("or")),
                ("conditions", condition)
            ]));
    }

    method: _processShotInfoForNeighbors (void; int cutOrder, (void; StringMap[]) afterFunc, EntityFields fields)
    {
        deb ("ShotgunState _processShotInfoForNeighbors cutOrder %s\n" % cutOrder);
        _recordsReturnedLast = fields.size();

        try
        {
        let coFieldValues = fields.extractField(shotgun_fields.fieldNameMap.find("cutOrder"));

        deb ("    checking %d possible shots\n" % coFieldValues.size());
        let maxMin = -1,
            minMax = -1,
            maxMinID = -1,
            minMaxID = -1;
        for_index (i; coFieldValues)
        {
            let (id, cov) = coFieldValues[i],
                cos = shotgun_fields.prettyPrintValue(cov),
                co = shotgun_fields.actualCutOrder(cos);

            deb ("    checking id %s co %s cos %s cov %s\n" % (id, co, cos, cov));
            if (co < 0) continue;
            //  XXX  IMD uses "cutOrders" that have holes in them so
            //  the matching has to be fuzzier than the below.
            //
            //if (co == cutOrder-1 || co == cutOrder+1) targetIDs.push_back(id);
            if (co < cutOrder && (co > maxMin || maxMinID == -1))
            {
                maxMin = co;
                maxMinID = id;
            }
            else
            if (co > cutOrder && (co < minMax || minMaxID == -1))
            {
                minMax = co;
                minMaxID = id;
            }
        }
        int[] targetIDs;
        if (minMaxID != -1) targetIDs.push_back(minMaxID);
        if (maxMinID != -1) targetIDs.push_back(maxMinID);

        if (targetIDs.size() == 0) 
        {
            afterFunc (StringMap[]());
            return;
        }

        [Value] conditionList;
        for_each (id; targetIDs) 
        {
            //  XXX Again we are assuming that cut order is stored
            //  on the Shot entity.
            Value shotStruct = Struct ([
                ("id", Int(id)),
                ("type", String("Shot"))
            ]);
            Value singleVersionCondition = Struct ([
                ("path", String("entity")),
                ("relation", String("is")),
                ("values", Array([ shotStruct ]))
            ]);

            conditionList = singleVersionCondition : conditionList;
        }
        Value condition = Array(conditionList);

        _shotgunServer.find(
            "Version",
            shotgun_fields.fieldListByEntityType("Version"),
            _processInfoFields (int[](),"Version",string[](),StringMap[](),afterFunc, false, ),
            Struct( [
                ("logical_operator", String("or")),
                ("conditions", condition)
            ]));
        }
        catch (object obj)
        {
            print ("ERROR: _processShotInfoForNeighbors: %s\n" % string(obj));
        }
    }

    method: collectNeighborInfos (void; 
            int cutOrder,
            int project,
            int sequence,
            (void; StringMap[]) afterFunc)
    {
        deb ("collectNeightborInfos cutOrder %s project %s sequence %s\n" % (cutOrder, project, sequence));
        Value conditions;

        let entityThatLinksToSeq = shotgun_fields.entityTypeMap.find("sequence");
        if (sequence != -1 && entityThatLinksToSeq == "Shot")
        {
            deb ("    using sequence condition\n");
            let realSeqEntity = shotgun_fields.prettyNameMap.find("sequence");
            Value sequenceStruct = Struct ([
                ("id", Int(sequence)),
                ("type", String(realSeqEntity))
            ]);
            //  XXX assuming here that the sequence id is a field on
            //  the Shot entity.  But field can have any name.
            let seqFieldName = shotgun_fields.fieldNameMap.find("sequence");
            Value sequenceCondition = Struct ([
                ("path", String(seqFieldName)),
                ("relation", String("is")),
                ("values", Array([ sequenceStruct ]))
            ]);

            conditions = Array([ sequenceCondition ]);
        }
        else 
        {
            deb ("    using project condition\n");
            Value projStruct = Struct ([
                ("id", Int(project)),
                ("type", String("Project"))
            ]);
            Value projectCondition = Struct ([
                ("path", String("project")),
                ("relation", String("is")),
                ("values", Array([ projStruct ]))
            ]);
            conditions = Array([ projectCondition ]);
        }

        _shotgunServer.find(
            "Shot",
            shotgun_fields.fieldListByEntityType("Shot"),
            _processShotInfoForNeighbors (cutOrder, afterFunc, ),
            Struct( [
                ("logical_operator", String("or")),
                ("conditions", conditions)
            ]));

        deb ("    collectNeightborInfos done\n");
    }
}

}
