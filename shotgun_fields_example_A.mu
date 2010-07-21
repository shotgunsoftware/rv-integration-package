

"""
This config module 

* Uses "Scene" entities instead of Sequences
* Gets the Project from the Shot entity 
* Holds its cut in/out information on the Version
* Holds min/max frame info on the Version
* 
""";

require runtime;

module: shotgun_fields_config_A
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
    ("sequence",           "Scene",         "sg_scene",           "entity",      "Shot",    false),
    ("project",            "Project",       "project",            "entity",      "Shot", false),
    ("task",               "Task",          "sg_task",            "entity",      "Version", false),
    ("user",               "Artist",        "user",               "entity",      "Version", false),

    //
    //  Media types.  For each media type whose path is stored
    //  per version, you must specify path, pixel aspect, and slate boolian.
    //  Corresponding "swap to" menu items and prefs will be
    //  generated accordingly.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("mt_Movie",           "Path To Movie", "sg_quicktime_file",   "text",        "Version", false),
    ("mt_Movie_aspect",    "none",          "none",                "float",       "Version", true),
    ("mt_Movie_hasSlate",  "none",          "sg_slate",            "checkbox",    "Version", true),

    ("mt_Frames",          "Path To Frames","sg_source_files",     "text",        "Version", false),
    ("mt_Frames_aspect",   "none",          "sg_pixel_aspect",     "float",       "Version", true),
    ("mt_Frames_hasSlate", "none",          "sg_slate",            "checkbox",    "Version", true),

    //
    //  Editorial information.  Can be stored on any entity, or computed
    //  from other information.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("frameMin",           "Start Frame",   "cut_in",             "number",      "Shot", false),
    ("frameMax",           "End Frame",     "cut_out",            "number",      "Shot", false),
    ("frameIn",            "In Frame",      "sg_cut_in",          "number",      "Shot", false),
    ("frameOut",           "Out Frame",     "sg_cut_end",         "number",      "Shot", false),

    //
    //  Unlike the above, the "cutOrder" must be a field on the
    //  Shot entity.  It can be any name or type, but the
    //  "actualCutOrder" function defined below must be able to
    //  generate an int from this field.
    //
    ("cutOrder",           "Cut Order",     "sg_cont_order",      "number",      "Shot",    true),

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
    ("shotStatus",         "Shot Status",   "sg_status_list",     "status_list", "Shot",    false),
    ("assetStatus",        "Asset Status",  "sg_status_list",     "status_list", "Asset",   false),
    ("department",         "Department",    "sg_system_task_type","system_task_type","Task",false),
    ("sceneName",          "Scene Name",    "sg_scene_name",      "text",        "Scene", false),
    ("sceneStatus",        "Scene Status",  "sg_status_list",     "status_list", "Scene", false)
    };

    return descriptors;
};

function: actualCutOrder (int; string cutOrderValue)
{
    let parts = cutOrderValue.split("_"),
        co = if (parts.size() == 2) then int(parts[1]) else 0;

    //  print ("actualCutOrder %s co %s\n" % (cutOrderValue, co));
    return co;
    
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
        "department",
        "shot",
        "shotStatus",
        "sequence",
        "sceneName",
        "asset",
        "assetStatus",
        "project",
        "mt_Movie",
        "mt_Frames"
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
    //  stored on entities.  For example:
    //
    data.add ("mt_Movie_aspect", "1");
    data.add ("mt_Frames_aspect", "1");


    data.add ("mt_Frames_hasSlate", "false");
    data.add ("mt_Movie_hasSlate", "true");

    //
    //  Unpack IMD file reference
    //
    let movie = data.find("mt_Movie");
    if (movie neq nil)
    {
        //  print ("************************ movie %s\n" % movie);
        let paths = regex.smatch("name_file://///[^/][^/]*([^|]*)\|", movie);
        //  print ("************************ %s\n" % paths);
        if (paths neq nil && paths.size() > 0) 
        {
            data.add("mt_Movie", paths.back());
        }
    }

    let maxF = data.find("frameMax"),
        outF = data.find("frameOut");

    if ((maxF eq nil || maxF == "nil") && (outF neq nil && outF != "nil")) 
    { 
        data.add ("frameMax", outF);
    }
    data.add ("frameMin", "1001");

    if (runtime.build_os() == "WINDOWS")
    {
        let frames = data.find("mt_Frames"),
            movie = data.find("mt_Movie");

        if (frames neq nil && !regex.match("^[a-zA-Z]:", frames))
        {
            frames = "c:" + frames;
            data.add("mt_Frames", frames);
        }
        if (movie neq nil && !regex.match("^[a-zA-Z]:", movie))
        {
            movie = "c:" + movie;
            data.add("mt_Movie", movie);
        }
    }
}

}
