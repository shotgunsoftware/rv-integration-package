
module: shotgun_fields_config_G
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
    //  "https://tweak.shotgunstudio.com 4b1676497a208c845b12f5c6734daf9d6e7c6274 http://tweak.shotgunstudio.com 4b1676497a208c845b12f5c6734daf9d6e7c6274"
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
    //("sequence",           "Sequence",      "sg_sequence",        "entity",      "Shot",    false),
    ("sequence",           "Sequence",      "sg_for_sequence",    "entity",      "Version",    false),
    ("project",            "Project",       "project",            "entity",      "Version", false),
    ("artist",             "Artist",        "user",               "entity",      "Version", false),
    //("task",               "Task",          "sg_task",            "entity",      "Version", false),
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
    ("mt_Frames_aspect",   "Frames Pixel Aspect","sg_aspect",     "float",       "Version", true),
    ("mt_Frames_hasSlate", "Frames Have Slate","sg_hasslate",     "checkbox",    "Version", true),

    //
    //  Editorial information.  Can be stored on any entity, or computed
    //  from other information.
    //
    // name                prettyName       fieldName             fieldType      entityType compute
    ("frameMin",           "Min Frame",     "sg_first_frame",     "number",      "Version", true),
    ("frameMax",           "Max Frame",     "sg_last_frame",      "number",      "Version", false),
    ("frameIn",            "In Frame",      "sg_cut_in",          "number",      "Shot", false),
    ("frameOut",           "Out Frame",     "sg_cut_out",         "number",      "Shot", false),

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
    ("department",         "Department",    "sg_version_type",    "text",        "Version", false),
    ("status",             "Status",        "sg_status_list",     "status_list", "Version", false),
    ("shotStatus",         "Shot Status",   "sg_status_list",     "status_list", "Shot",    false),
    ("assetStatus",        "Asset Status",  "sg_status_list",     "status_list", "Asset",   false)
    };

    return descriptors;
};

//
//  We make an attempt here to retrieve an ordering from any number
//  we find in the shot name name.  Not very robust, but better than
//  nothing.
//

function: actualCutOrder (int; string cutOrderValue)
{
    let parts = regex.smatch ("[^0-9]*([0-9][0-9]*)[^0-9]*$", cutOrderValue);

    return int(parts.back());
}

function: displayOrder (string[]; )
{
    string[] fo = string [] {
        "name",
        "description",
        "status",
        "artist",
        "created",
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

    //  Assuming that frameMin is always 1
    //
    data.add ("frameMin", "1");

    //  Assuming that we always have a slate (if not rv will just
    //  display the first frame twice, i think).
    //
    data.add ("mt_Frames_hasSlate", "true");

    //  Assuming that pixel aspect is always 1.0
    //
    data.add ("mt_Frames_aspect", "1.0");

    //  Published frame paths have '%06d' in them, so swap with
    //  something more rv-friendly.
    //
    let path = data.find("mt_Frames");
    if (path neq nil)
    {
        data.add ("mt_Frames", regex("%0[1-9]d").replace(path, "#"));
    }

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
