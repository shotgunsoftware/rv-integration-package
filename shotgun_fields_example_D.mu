
require runtime;

module: shotgun_fields_config_D
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
    ("department",         "Department",    "sg_department",      "entity",      "Version", false),
    ("user",               "Artist",        "user",               "entity",      "Version", false),
    ("humanUser",          "HumanUser",     "user",               "entity",      "Version", false),
    ("scene",              "Scene",         "sg_scene",           "entity",      "Shot",    false),
    ("tankRev",            "Tank Revision", "sg_tank_revision",   "entity",      "Version", false),
    ("publishEvent",       "PublishEvent",  "tankRev",            "entity",      "Version", true),

    //
    //  Media types.  For each media type whose path is stored
    //  per version, you must specify path, pixel aspect, and slate boolian.
    //  Corresponding "swap to" menu items and prefs will be
    //  generated accordingly.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("mt_Movie",           "Path To Movie", "sg_path_to_qt",      "text",        "Version", false),
    ("mt_Movie_aspect",    "none",          "none",               "float",       "Version", true),
    ("mt_Movie_hasSlate",  "none",          "sg_hasslate",        "checkbox",    "Version", false),

    ("mt_Frames",          "Path To Frames","sg_path_to_frames",  "text",        "Version", false),
    ("mt_Frames_aspect",   "none",          "none",               "float",       "Version", true),
    ("mt_Frames_hasSlate", "none",          "none",               "checkbox",    "Version", true),

    //
    //  Editorial information.  Can be stored on any entity, or computed
    //  from other information.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("frameMin",           "Min Frame",     "sg_start",           "number",      "Version", false),
    ("frameMax",           "Max Frame",     "sg_end",             "number",      "Version", false),
    ("frameIn",            "In Frame",      "sg_cut_in",          "number",      "Shot", false),
    ("frameOut",           "Out Frame",     "sg_cut_out",         "number",      "Shot", false),

    //
    //  Unlike the above, the "cutOrder" must be a field on the
    //  Shot entity.  It can be any name or type, but the
    //  "actualCutOrder" function defined below must be able to
    //  generate an int from this field.
    //
    ("cutOrder",           "Cut Order",     "sg_cutorder",     "number",      "Shot",    false),

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
    ("seqStatus",          "Sequence Status", "sg_status_list",   "status_list", "Sequence",false),
    ("assetStatus",        "Asset Status",  "sg_status_list",     "status_list", "Asset",   false),
    ("userEmail",          "Artist Email",  "email",              "text",        "HumanUser",false),
    ("tankRevDesc",        "Tank Rev Description",  "description","text",        "PublishEvent",false),
    //("tags",               "Tags",          "tag_list",           "multi_entity","Version", false),
    ("cameraType",         "Camera Type",   "sg_cameratype",      "text",        "Shot",    false)
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
        "userEmail",
        "created",
        "id",
        "department",
        "shot",
        "shotStatus",
        "cameraType",
        "sequence",
        "seqStatus",
        "scene",
        "asset",
        "assetStatus",
        "tankRev",
        "tankRevDesc",
        //"tags",
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
    //  Here we just say that the pixel aspect ratio in a version's
    //  movie media will be the same as in the frames media.  
    //

    //data.add ("mt_Movie_aspect", data.find("mt_Frames_aspect"));

    //
    //  Or if you alway have square pixels in your movies,
    //
    data.add ("mt_Movie_aspect", "1.0");
    data.add ("mt_Frames_aspect", "1.0");

    data.add ("mt_Frames_hasSlate", "false");

    //  XXX  This is hacky, since cut in data is missing, and cut
    //  out is an offset from cutIn
    //
    /*
    let cutInString = data.find("frameIn"),
        cutOut = int(data.find("frameOut")) + 101,
        cutIn = if (cutInString == "0") then "101" else cutInString;

    data.add ("frameIn", cutIn);
    data.add ("frameOut", string(cutOut));
    */

    /*
    print ("***********************************INFO\n");
    print ("%s" % data.toString());
    print ("***************************************\n");
    */

    /*
    //
    //  Example: you can mod your paths this way, or by using
    //  RV_PATHSWAP_* environment variables (ask alan).
    //
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
