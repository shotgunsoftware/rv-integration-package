
"""
""";
require runtime;

module: shotgun_fields_config_B
{

require shotgun_stringMap;
StringMap := shotgun_stringMap.StringMap;

function: serverMap (string; )
{
    //
    //  If you decide to store your servers and script keys here
    //  instead of in an environment variable, edit the below to
    //  return a string of pairs of server urls and corresponding
    //  script keys separated by spaces, like this:
    //
    //  return "https://tweak.shotgunstudio.com 4b1676497a208c845b12f5c6734daf9d6e7c6274 http://blah.shotgunstudio.com 4b1676497a208c845b12f5c6734daf9d6e7c6274"
    //
    //  You can have as many server/key pairs as you want, and the
    //  first will be considered the default.
    //
    return nil;
}

function: fieldDescriptors((string, string, string, string, string, bool)[]; )
{
    //
    //  In all the below, do NOT change the values in the "name"
    //  column.  These are the keys, by which RV will index these
    //  arrays of information.
    //
    (string, string, string, string, string, bool)[] descriptors = {
    //
    //  Entity fields.  These may be any number of hops away from
    //  the  Version.  Note the shot/asset fields.  The "link"field
    //  may point to either a Shot or an Asset.  Both are supported
    //  by specifying the Link field and then that the Shot and Asset
    //  fields are computed from the Link field.  The computation is
    //  internal and not part of the "compute" function defined
    //  below.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("link",               "Link",          "entity",             "entity",      "Version", false),
    ("shot",               "Shot",          "link",               "entity",      "Version", true),
    ("asset",              "Asset",         "link",               "entity",      "Version", true),
    //("sequence",         "Sequence",      "sg_sequence",        "entity",      "Shot",    false),
    ("project",            "Project",       "project",            "entity",      "Version", false),
    //("task",             "Task",          "sg_task",            "entity",      "Version", false),
    ("user",               "Artist",        "user",               "entity",      "Version", false),
    ("element",            "Element",       "sg_element_link",    "entity",      "Version", false),
    
    //
    //  Media types.  For each media type whose path is stored
    //  per version, you must specify path, pixel aspect, and slate boolian.
    //  Corresponding "swap to" menu items and prefs will be
    //  generated accordingly.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("mt_Movie",           "Path To Movie", "sg_shotgun_path",   "text",        "Element", false),
    ("mt_Movie_aspect",    "none",          "none",               "float",       "Element", true),
    ("mt_Movie_hasSlate",  "none",          "sg_slate",           "checkbox",    "Element", true),

    ("mt_ProxyFrames",          "Path To Proxy Frames","sg_proxy_path",  "text",        "Element", false),
    ("mt_ProxyFrames_aspect",   "none",          "sg_pixel_aspect",    "float",       "Element", true),
    ("mt_ProxyFrames_hasSlate", "none",          "sg_slate",           "checkbox",    "Element", true),

    ("mt_FullFrames",       "Path To Full Frames","sg_plate_path",           "text",        "Element", false),
    ("mt_FullFrames_aspect","none",          "none",               "float",       "Element", true),
    ("mt_FullFrames_hasSlate","none",        "none",               "checkbox",    "Element", true),

    //
    //  Editorial information.  Can be stored on any entity, or computed
    //  from other information.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("frameMin",           "Min Frame",     "head_in",       "number",      "Shot", false),
    ("frameMax",           "Max Frame",     "tail_out",       "number",      "Shot", false),
    ("frameIn",            "In Frame",      "cut_in",        "number",      "Shot", false),
    ("frameOut",           "Out Frame",     "cut_out",       "number",      "Shot", false),

    //
    //  Unlike the above, the "cutOrder" must be a field on the
    //  Shot entity.  It can be any name or type, but the
    //  "actualCutOrder" function defined below must be able to
    //  generate an int from this field.
    //
    ("cutOrder",           "Cut Order",     "sg_cut_order",     "number",      "Shot",    false),

    //  
    //  Essential.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("id",                 "ID",            "id",                 "number",      "Version", false),

    //  
    //  Arbitrary fields for the info widget can go here.  Can be
    //  fields on any entity "reachable" from the Version enitity.
    //  But any entity that appears in  the entityType field below
    //  must appear as a fieldType entry above.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("name",               "Name",          "code",               "text",        "Version", false),
    ("description",        "Description",   "description",        "text",        "Version", false),
    ("created",            "Created",       "created_at",         "date_time",   "Version", false),
    ("status",             "Status",        "sg_status_list",     "status_list", "Version", false),
    ("shotStatus",         "Shot Status",   "sg_status_list",  "status_list",    "Shot",    false),
    ("fileType",           "Media File Type", "sg_format", "string",      "Element",    false),
    ("elemName",           "Element Name",  "code",             "string",        "Element",    false)
    //("assetStatus",        "Asset Status",  "sg_status_list",     "status_list", "Asset",   false),
    //("taskType",           "Department",    "sg_system_task_type","system_task_type","Task",false),
    //("seqPriority",        "Sequence Priority","sg_priority",     "list",        "Sequence",false)
    };

    return descriptors;
};

function: actualCutOrder (int; string cutOrderValue)
{
    return int(cutOrderValue);
}

function: displayOrder (string[]; )
{
    string[] fo = string [] {
        "name",
        "description",
        "status",
        "user",
        "created",
        "id",
        //"taskType",
        "shot",
        "shotStatus",
        //"sequence",
        //"seqPriority",
        "asset",
        //"assetStatus",
        "project",
        "mt_Movie",
        "mt_ProxyFrames",
        "mt_FullFrames"
    };
}

function: fieldsCompute (void; StringMap data, bool incremental)
{
    //  
    //  When 'incremental' is true, we only want to compute fields
    //  that "lead" to other fields (like entity fields).  In
    //  general, we only need to compute field values after all
    //  entities are queried, ie when 'incremental' is false.
    //
    if (incremental) return;

    //
    //  Here you can compute any fields that are not stored on
    //  entities, but which can be computed from fields which _are_
    //  stored on entities.

    data.add ("mt_Movie_aspect", "1.0");
    data.add ("mt_Movie_hasSlate", "false");

    data.add ("mt_ProxyFrames_aspect", "1.0");
    data.add ("mt_ProxyFrames_hasSlate", "false");

    data.add ("mt_FullFrames_aspect", "1.0");
    data.add ("mt_FullFrames_hasSlate", "false");

    //
    //  Or if you alway have square pixels in your movies,
    //
    //  data.add ("#moviePixelAspect", "1.0");


    //  data.add ("mt_Frames_hasSlate", "true");

    //  data.add ("mt_AltFrames", data.find("mt_Frames"));
    //  data.add ("mt_AltFrames_aspect", data.find("mt_Frames_aspect"));
    //  data.add ("mt_AltFrames_hasSlate", data.find("mt_Frames_hasSlate"));

    if (runtime.build_os() == "WINDOWS")
    {
        let proxyFrames = data.find("mt_ProxyFrames"),
            fullFrames = data.find("mt_FullFrames"),
            movie = data.find("mt_Movie"),
            type = data.find("fileType"),
            elemName = data.find("elemName");

        print ("old mt_Movie '%s'\n" % movie);
        print ("old mt_FullFrames '%s'\n" % fullFrames);
        print ("old mt_ProxyFrames '%s'\n" % proxyFrames);
        print ("elemName '%s' type '%s'\n" % (elemName, type));

        if (movie neq nil)
        {
            let paths = regex.smatch("shotgun://(.*$)", movie);
            print ("paths '%s'\n" % paths);
            if (paths neq nil && paths.size() > 0) 
            {
                let mypath = regex.replace("&gt;", paths.back(), "/") + elemName + ".mov";
                mypath = regex.replace("renders", mypath, "shotgun");
                print ("mypath '%s'\n" % mypath);
                data.add("mt_Movie", mypath);
            }
        }

        if (proxyFrames neq nil)
        {
            let paths = regex.smatch("shotgun://(.*$)", proxyFrames);
            print ("paths '%s'\n" % paths);
            if (paths neq nil && paths.size() > 0) 
            {
                let mypath = regex.replace("&gt;", paths.back(), "/") + elemName + ".#.jpg";
                print ("mypath '%s'\n" % mypath);
                data.add("mt_ProxyFrames", mypath);
            }
        }

        if (fullFrames neq nil)
        {
            let paths = regex.smatch("shotgun://(.*$)", fullFrames);
            print ("paths '%s'\n" % paths);
            if (paths neq nil && paths.size() > 0) 
            {
                let mypath = regex.replace("&gt;", paths.back(), "/") + elemName + ".#." + type;
                print ("mypath '%s'\n" % mypath);
                data.add("mt_FullFrames", mypath);
            }
        }

        /*
        print ("new mt_Movie '%s'\n" % movie);
        print ("new mt_FullFrames '%s'\n" % fullFrames);
        print ("new mt_ProxyFrames '%s'\n" % proxyFrames);
        */
    }
}

}
