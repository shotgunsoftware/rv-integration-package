
require runtime;

module: shotgun_fields_config_F
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
    ("artist",             "Artist",        "user",             "entity",      "Version", false),
    ("task",               "Task",          "sg_task",            "entity",      "Version", false),
    //("scene",              "Scene",         "sg_scene",           "entity",      "Shot",    false),
    //("tankRev",            "Tank Revision", "sg_tank_revision",   "entity",      "Version", false),
    //("publishEvent",       "PublishEvent",  "tankRev",            "entity",      "Version", true),

    //
    //  Media types.  For each media type whose path is stored
    //  per version, you must specify path, pixel aspect, and slate boolian.
    //  Corresponding "swap to" menu items and prefs will be
    //  generated accordingly.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("mt_Frames",          "Path To Frames","sg_path_to_frames",  "text",        "Version", false),
    ("mt_Frames_aspect",   "Frames Pixel Aspect","sg_aspect", "float",           "Version", false),
    ("mt_Frames_hasSlate", "Frames Have Slate","sg_hasslate", "checkbox",           "Version", false),

    //
    //  Editorial information.  Can be stored on any entity, or computed
    //  from other information.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("frameMin",           "Min Frame",     "sg_first_frame",     "number",      "Version", false),
    ("frameMax",           "Max Frame",     "sg_last_frame",      "number",      "Version", false),
    ("frameRange",          "Frame Range",   "frame_range",        "number",      "Version", false),
    //  
    //  frameIn and frameOut will be computed from frame range.
    //
    ("frameIn",            "In Frame",      "none",          "number",      "Shot", true),
    ("frameOut",           "Out Frame",     "none",         "number",      "Shot", true),

    //
    //  Unlike the above, the "cutOrder" must be a field on the
    //  Shot entity.  It can be any name or type, but the
    //  "actualCutOrder" function defined below must be able to
    //  generate an int from this field.
    //
    ("cutOrder",           "Cut Order",     "code",     "number",      "Shot",    false),

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
    ("department",         "Department",    "step",               "text",        "Task", false),
    ("status",             "Status",        "sg_status_list",     "status_list", "Version", false),
    ("shotStatus",         "Shot Status",   "sg_status_list",     "status_list", "Shot",    false),
    ("assetStatus",        "Asset Status",  "sg_status_list",     "status_list", "Asset",   false)
    };

    return descriptors;
};

function: actualCutOrder (int; string cutOrderValue)
{
    let parts = regex.smatch ("[^0-9]*([0-9][0-9]*$)", cutOrderValue);

    return int(parts.back());
}

function: displayOrder (string[]; )
{
    string[] fo = string [] {
        "name",
        "description",
        "status",
        "humanUser",
        "created",
        "task",
        "department",
        "shot",
        "shotStatus",
        "sequence",
        "asset",
        "assetStatus",
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
    //  stored on entities.

    let frameRange = data.find("frameRange");
    if (frameRange neq nil)
    {
        let parts = regex.smatch ("(^[0-9][0-9]*)-([0-9][0-9]*$)", frameRange);
        if (parts.size() == 3)
        {
            data.add ("frameMin", parts[parts.size()-2]);
            data.add ("frameMax", parts[parts.size()-1]);
        }
    }
    else print ("WARNING: illegal frame range '%s'\n" % frameRange);

    //
    //  Uncomment to dump the shotgun data to terminal
    //
    /*
    print ("***********************************INFO\n");
    print ("%s" % data.toString());
    print ("***************************************\n");
    */
}

}
