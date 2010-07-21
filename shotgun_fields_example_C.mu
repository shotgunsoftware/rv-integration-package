
require runtime;

module: shotgun_fields_config_C
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
    ("sequence",           "Sequence",      "sg_sequence",        "entity",      "Shot",    false),
    ("project",            "Project",       "project",            "entity",      "Version", false),
    //("task",               "Task",          "sg_task",            "entity",      "Version", false),
    ("user",               "Artist",        "user",               "entity",      "Version", false),

    //
    //  Media types.  For each media type whose path is stored
    //  per version, you must specify path, pixel aspect, and slate boolian.
    //  Corresponding "swap to" menu items and prefs will be
    //  generated accordingly.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("mt_Source",           "Source Path",   "sg_source_path",     "text",        "Version", false),
    ("mt_Source_aspect",    "none",          "none",               "float",       "Version", true),
    ("mt_Source_hasSlate",  "none",          "none",               "checkbox",    "Version", true),

    ("mt_QT",               "QT Path",       "sg_qt_path",         "text",        "Version", false),
    ("mt_QT_aspect",        "none",          "none",               "float",       "Version", true),
    ("mt_QT_hasSlate",      "none",          "sg_has_slate",       "checkbox",    "Version", false),

    //
    //  Editorial information.  Can be stored on any entity, or computed
    //  from other information.
    //
    // name                prettyName       fieldName        fieldType      entityType compute
    ("frameMin",           "Min Frame",     "head_in",       "number",      "Shot", false),
    ("frameMax",           "Max Frame",     "tail_out",      "number",      "Shot", false),
    ("frameIn",            "In Frame",      "cut_in",        "number",      "Shot", false),
    ("frameOut",           "Out Frame",     "cut_out",       "number",      "Shot", false),
    //  ("frameRange",         "Frame Range",   "sg_frame_range",     "text",        "Version", false),

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
    ("shotStatus",         "Shot Status",   "sg_status_list",     "status_list", "Shot",    false),
    ("assetStatus",        "Asset Status",  "sg_status_list",     "status_list", "Asset",   false),
    ("department",         "Role",          "sg_role",            "text","Version",false) 
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
        "department",
        "shot",
        "shotStatus",
        "sequence",
        //"seqPriority",
        "asset",
        "assetStatus",
        "project",
        "mt_QT",
        "mt_Source"
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
    //  stored on entities.  Or field data can be modified to fit
    //  the needs of RV.
    //

    //
    //  Here we just say that the pixel aspect ratio as always 1.0
    //
    data.add("mt_Source_aspect", "1.0");
    data.add("mt_QT_aspect", "1.0");

    //
    //  XXX We claim here that source never has slate.
    //
    data.add("mt_Source_hasSlate", "false");

    if (runtime.build_os() == "LINUX")
    {
        let source = data.find("mt_Source");
        if (source neq nil)
        {
            source = regex.replace ("%04d", source, "#");
            source = regex.replace ("%v", source, "r");
	    data.add("mt_Source", source);
        }
    }
    /*
    if (runtime.build_os() == "WINDOWS")
    {
        let frames = data.find("mt_Frames"),
            altframes = data.find("mt_AltFrames"),
            movie = data.find("mt_Movie");

        if (frames neq nil && !regex.match("^[a-zA-Z]:", frames))
        {
            frames = "c:" + frames;
            data.add("mt_Frames", frames);
        }
        if (altframes neq nil && !regex.match("^[a-zA-Z]:", altframes))
        {
            altframes = "c:" + altframes;
            data.add("mt_AltFrames", altframes);
        }
        if (movie neq nil && !regex.match("^[a-zA-Z]:", movie))
        {
            movie = "c:" + movie;
            data.add("mt_Movie", movie);
        }
    }
    */
}

}
