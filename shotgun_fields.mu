
module: shotgun_fields 
{

require shotgun_stringMap;
require commands;
require runtime;
use shotgun_xmlrpc;
use Value;

StringMap := shotgun_stringMap.StringMap;

\: deb(void; string s) { if (false) print("fields: " + s); }

class: FieldsConfig
{
    (string; ) 
            serverMap;
    ((string, string, string, string, string, bool)[]; ) 
            fieldDescriptors;
    (int; string) 
            actualCutOrder;
    (string[]; ) 
            displayOrder;
    (void; StringMap, bool) 
            fieldsCompute;
};


global FieldsConfig _fieldsConfig = nil;

function:_initFieldsConfig (void; string configStyle)
{
    deb ("_initFieldsConfig style '%s'\n" % configStyle);
    string mName;
    if (configStyle != "")
    {
        mName = "shotgun_fields_config_" + configStyle;
        if (!runtime.load_module(mName)) 
        {
            print ("ERROR: Config style '%s' not found\n" % configStyle);
            mName = "";
        }
    }
    if (mName == "")
    {
        mName = "shotgun_fields_config_custom";
        if (!runtime.load_module(mName)) 
        {
            print ("ERROR: custom config not found and no configStyle set\n");
            throw exception("No config module found");
        }
    }
    for_each (t; runtime.module_locations())
    {
        if (t._0 == mName) print ("INFO: loaded shotgun config module '%s' (%s)\n" % t);
    }

    _fieldsConfig = FieldsConfig();

    runtime.name name;

    name = runtime.intern_name("%s.serverMap" % mName);
    _fieldsConfig.serverMap = runtime.lookup_function(name);

    name = runtime.intern_name("%s.fieldDescriptors" % mName);
    _fieldsConfig.fieldDescriptors = runtime.lookup_function(name);

    name = runtime.intern_name("%s.actualCutOrder" % mName);
    _fieldsConfig.actualCutOrder = runtime.lookup_function(name);

    name = runtime.intern_name("%s.displayOrder" % mName);
    _fieldsConfig.displayOrder = runtime.lookup_function(name);

    name = runtime.intern_name("%s.fieldsCompute" % mName);
    _fieldsConfig.fieldsCompute = runtime.lookup_function(name);
}

class: FieldDescriptor 
{
    string name;;
    string prettyName;
    string fieldName;
    string fieldType;
    string entityType;

    //
    //  If this field is to be computed instead of retrieved from
    //  DB, set compute to true;
    //
    bool compute;

    method: FieldDescriptor (FieldDescriptor; 
            string n,
            string pn,
            string fn,
            string ft,
            string et,
            bool c)
    {
        name = n; 
        prettyName = pn;
        fieldName = fn;
        fieldType = ft;
        entityType = et;
        compute = c;
    }
};

global FieldDescriptor[] fields;
global StringMap prettyNameMap, fieldNameMap, fieldTypeMap, entityTypeMap, computeMap;
global bool initialized = false;

function: init (void; string configStyle) 
{ 
    if (initialized) return;

    _initFieldsConfig(configStyle);

    fields = FieldDescriptor[]();
    try
    {
        (string, string, string, string, string, bool)[] fd = _fieldsConfig.fieldDescriptors();

        for_each (t; fd)
        {
            fields.push_back (FieldDescriptor (t._0, t._1, t._2, t._3, t._4, t._5));
        }
    }
    catch (object obj)
    {
        print ("ERROR: custom config fieldDescriptors() error: %s\n" % string(obj));
    }
    deb ("fields %s\n" % fields);

    prettyNameMap = StringMap(30);
    fieldNameMap  = StringMap(30);
    fieldTypeMap  = StringMap(30);
    entityTypeMap = StringMap(30);
    computeMap    = StringMap(30);

    for_each (f; fields)
    {
        prettyNameMap.add (f.name, f.prettyName);
        fieldNameMap.add  (f.name, f.fieldName);
        fieldTypeMap.add  (f.name, f.fieldType);
        entityTypeMap.add (f.name, f.entityType);
        computeMap.add    (f.name, string(f.compute));
    }

    deb ("\nfields init complete\n\n");
    initialized = true;
}

function: compute (void; StringMap data, bool incremental=true)
{
    if (!initialized) throw exception("ERROR: shotgun_fields.compute() called before init()\n");

    _computeInternalPre (data, incremental);

    try 
    {
        _fieldsConfig.fieldsCompute (data, incremental);
    }
    catch (object obj)
    {
        print ("ERROR: custom config fieldsCompute() error: %s\n" % string(obj));
    }

    _computeInternalPost (data, incremental);

    deb ("compute() complete\n");
}

function: displayOrder (string[]; )
{
    if (!initialized) throw exception("ERROR: shotgun_fields.displayOrder() called before init()\n");

    try
    {
        return _fieldsConfig.displayOrder();
    }
    catch (object obj)
    {
        print ("ERROR: custom config displayOrder() error: %s\n" % string(obj));
        return string[]();
    }
}

function: serverMap (string; )
{
    if (!initialized) throw exception("ERROR: shotgun_fields.serverMap() called before init()\n");

    try 
    {
        return if (_fieldsConfig.serverMap neq nil) then _fieldsConfig.serverMap() else nil;
    }
    catch (object obj)
    {
        print ("ERROR: custom config serverMap() error: %s\n" % string(obj));
        return nil;
    }
}

function: actualCutOrder (int; string v)
{
    if (!initialized) throw exception("ERROR: shotgun_fields.actualCutOrder() called before init()\n");

    try
    {
        return _fieldsConfig.actualCutOrder(v);
    }
    catch (object obj)
    {
        print ("ERROR: custom config actualCutOrder() error: %s\n" % string(obj));
        return int(v);
    }
}

//
//  Convenience functions
//

function: swapSlashes (string; string in)
{
    return regex.replace("\\\\", in, "/");
}

function: extractLocalPathValue (string; string value)
{
    if (regex("\|").match(value) && regex("link_type_local").match(value))
    {
        deb ("extractLocalPathValue '%s'\n" % value);

        let parts = value.split("|"),
            osStr = runtime.build_os(),
            prefStr = "local_path_" + (if (osStr == "LINUX") then "linux" else (if (osStr == "DARWIN") then "mac" else "windows")),
            re = regex("^" + prefStr + "_(.*)");

        deb ("    osStr '%s'\n" % osStr);
        deb ("    prefStr '%s'\n" % prefStr);
        deb ("    re '%s'\n" % re);
        for_each (p; parts)
        {
            deb ("    checking '%s'\n" % p);   
            if (re.match(p)) return swapSlashes(re.smatch(p)[1]);
        }

        return "no_local_path_for_" + osStr;
    }
    return swapSlashes(value);
}

function: extractEntityValueParts ((string,string,int); string value)
{
    string name = nil;
    string t = nil;
    int id = -1;

    let parts = value.split("|");
    if (parts.size() == 3) 
    {
        let reName = regex("^name_(.*)"),
            reType = regex("^type_(.*)"),
            reID = regex("^id_(.*)");

        for_each(p; parts)
        {
            if (reName.match(p)) name = reName.smatch(p)[1]; 
            if (reType.match(p)) t = reType.smatch(p)[1];
            if (reID.match(p))   id = int(reID.smatch(p)[1]);
        }
    }
    return (name, t, id);
}

function: mediaTypes (string[]; )
{
    let re = regex("^mt_([^_]*)$"),
        types = string[]();

    for_each (f; fields)
    {
        if (re.match(f.name)) 
        {
            types.push_back (re.smatch(f.name)[1]);
        }
    }

    return types;
}

function: mediaTypePathEmpty (bool; string mediaType, StringMap info)
{
    let name = "mt_" + mediaType;

    return info.fieldEmpty (name);
}

function: mediaTypePath (string; string mediaType, StringMap info)
{
    let name = "mt_" + mediaType;

    string path = info.find(name, true);
    if (path eq nil || path == "")
    {
        //  print ("WARNING: %s not set, using colorbars\n" % name);
        path = "smptebars,start=1,end=100.movieproc";
    }
    return extractLocalPathValue(path);
}

function: mediaTypePixelAspect (float; string mediaType, StringMap info)
{
    let name = "mt_" + mediaType + "_aspect";

    string pas = info.find(name);
    if (pas eq nil)
    {
        print ("ERROR: %s not set, assuming 1.0\n" % name);
        pas = "1.0";
    }
    return float(pas);
}

function: mediaTypeHasSlate (bool; string mediaType, StringMap info)
{
    let name = "mt_" + mediaType + "_hasSlate";

    string hss = info.find(name);
    if (hss eq nil)
    {
        print ("ERROR: %s not set, assuming false\n" % name);
        hss = "false";
    }
    return bool(hss);
}

function: mediaTypeFromPath (string; string path, StringMap info)
{

    for_each (t; mediaTypes())
    {
        if (mediaTypePath (t, info) == path) return t;
    }

    return "<no_type>";
}

function: fieldListByEntityType ([string]; string eType)
{
    deb ("fieldListByEntityType %s\n" % eType);
    [string] fieldNames;
    for_each (f; fields)
    {
        if (f.entityType == eType && f.compute == false)
        {
            //  print ("    adding %s\n" % f.name);
            fieldNames = f.fieldName : fieldNames;
        }
    }
    return fieldNames;
}

function: freshInfo (StringMap; )
{
    StringMap sm = StringMap(prettyNameMap.keys().size());
    for_each (k; prettyNameMap.keys())
    { 
        sm.add(k, nil);
    }
    return sm;
}

function: updateSourceInfo (void; int[] sourceNums, StringMap[] infos)
{
    deb ("updateSourceInfo sourceNums %s, infos:\n" % sourceNums); 
    for_each (info; infos) deb ("    info: %s\n" % info.toString("        "));
    for_index (i; sourceNums)
    {
        string infoProp = "sourceGroup%06d_source.tracking.info" % sourceNums[i];
        try { commands.newProperty (infoProp, commands.StringType, 1); }
        catch(...) { ; }
        try { commands.setStringProperty (infoProp, infos[i].toStringArray(), true); }
        catch(...) { ; }
    }
    updateSourceInfoStatus (sourceNums, "good");
}

function: updateSourceInfoStatus (void; int[] sourceNums, string status)
{
    deb ("updateSourceInfoStatus sourceNums %s status %s\n" % (sourceNums, status));
    for_index (i; sourceNums)
    {
        string statusProp = "sourceGroup%06d_source.tracking.infoStatus" % sourceNums[i];
        try { commands.newProperty (statusProp, commands.StringType, 1); }
        catch(...) { ; }
        commands.setStringProperty (statusProp, string[] {status}, true);
    }
}

function: infoFromSource (StringMap; int sourceNum)
{
    try
    {
        string[] info = commands.getStringProperty("sourceGroup%06d_source.tracking.info" % sourceNum);
        StringMap sm = StringMap(info);
        for_each (k; sm.keys())
        {
            if ("<nil>" == sm.find(k)) sm.add(k, nil);
        }
        return sm;
    }
    catch (...) { return nil; }
}

function: sourceHasEditorialInfo (bool; int sourceNum)
{
    let info = infoFromSource (sourceNum);

    if (info eq nil) return false;

    let edlFields = string[] { "frameMin", "frameMax", "frameIn", "frameOut" };
    try 
    {
        for_each (f; edlFields) if (info.find(f) eq nil || info.find(f) == "") return false;
    } 
    catch (...) { return false; }

    return true;
}

function: sourceHasField (bool; int sourceNum, string field)
{
    let info = infoFromSource (sourceNum);

    if (info eq nil) return false;

    try 
    {
        if (info.find(field) eq nil || info.find(field) == "") return false;
    }
    catch (...) { return false; }

    return true;
}

function: infoStatusFromSource (string; int sourceNum)
{
    try 
    {
        return commands.getStringProperty("sourceGroup%06d_source.tracking.infoStatus" % sourceNum).back();
    }
    catch (...) { return nil; }
}

function: prettyPrintValue (string; Value v)
{
    string s;

    case (v)
    {
        Nil         -> { s = "nil"; }
        Int i       -> { s = "%d" % i; }
        String str  -> { s = str; }
        Bool b      -> { s = if b then "true" else "false"; }
        Double f    -> { s = "%g" % f; }
        EmptyArray  -> { s = ""; }
        DateTime d  -> { s = "%04d-%02d-%02d %02d:%02d:%02d" % d; }

        Struct str ->
        { 
            for_each (p; str)
            {
                if (s != "") s += "|";
                s += p._0 + "_" + prettyPrintValue(p._1);
            }
        }

        Array a ->
        {
            /*
            s = "<array>";
            */
            s = "";
            for_each (e; a) s = s + prettyPrintValue(e) + " ";
        }

        Binary b ->
        {
            s = "<binary>";
            // print(o, utf8_to_string(to_base64(b)));
        }
    }

    return s;
}

//
//  Internal portion of compute()
//

documentation: """
_computeInternal handles fields of type "entity" that can link to more
than on type of entity.  The only example of this at the moment is
the "Link" field on Versions, which can point to either a Shot or an
Asset.

_computeInternalPre comes before user-level compute, Post comes
after.

Also, rv supports special environment variables in the media paths,
so support them here too.
""";

function: _computeInternalPre (void; StringMap data, bool incremental)
{
    deb ("_computeInternal inc %s\n" % incremental);
    for_each (f; fields)
    {
        if (f.fieldType == "entity" && f.compute ==  true)
        {
            deb ("    checking %s\n" % f.fieldName);
            let v = data.find(f.fieldName);
            deb ("    field %s v %s\n" % (f.fieldName, v));

            if (v neq nil)
            {
                let (name, t, id) = extractEntityValueParts (v);

                if (t == f.prettyName) data.add(f.name, v);
            }
            deb ("    checking %s done\n" % f.fieldName);
        }
    }
    if (!incremental)
    {
        deb ("    pathswap processing\n");
        //
        //  Swap out any ${RV_PATHSWAP_... variables in the media
        //  paths for their true values.
        //
        for_each (t; mediaTypes())
        {
            let key = "mt_" + t,
                mediaPath = data.find (key);

            if (mediaPath neq nil)
            {
                data.add (key, commands.undoPathSwapVars(mediaPath));
            }
        }
        deb ("    final field processing\n");
    }
}

function: _computeInternalPost (void; StringMap data, bool incremental)
{
    deb ("_computeInternalPostinc %s\n" % incremental);
    if (!incremental)
    {
        deb ("    final field processing\n");
        if (data.fieldEmpty ("frameMin"))
        {
            string mf = -int.max;

            if (! data.fieldEmpty("shot"))
            {
                print ("INFO: missing frameMin (%s) field, assuming '%s'\n" % (fieldNameMap.find("frameMin"), mf));
            }
            data.add ("frameMin", mf);
        }
        if (data.fieldEmpty ("frameMax"))
        {
            string mf = int.max;

            if (! data.fieldEmpty("shot"))
            {
                print ("INFO: missing frameMax (%s) field, assuming '%s'\n" % (fieldNameMap.find("frameMax"), mf));
            }
            data.add ("frameMax", mf);
        }
        if (data.fieldEmpty ("frameIn"))
        {
            string mf = data.find ("frameMin");

            if (! data.fieldEmpty("shot"))
            {
                print ("WARNING: missing frameIn (%s) field, assuming '%s'\n" % (fieldNameMap.find("frameIn"), mf));
            }
            data.add ("frameIn", mf);
        }
        if (data.fieldEmpty ("frameOut"))
        {
            string mf = data.find ("frameMax");

            if (! data.fieldEmpty("shot"))
            {
                print ("WARNING: missing frameOut (%s) field, assuming '%s'\n" % (fieldNameMap.find("frameOut"), mf));
            }

            data.add ("frameOut", mf);
        }

        let types = mediaTypes();

        for_each (t; types)
        {
            let pa = "mt_" + t + "_aspect",
                hs = "mt_" + t + "_hasSlate";

            if (data.fieldEmpty(pa)) data.add(pa, "0.0");
            if (data.fieldEmpty(hs)) data.add(hs, "true");
        }
    }
}

}
