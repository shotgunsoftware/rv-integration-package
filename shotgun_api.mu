
module: shotgun_api {
use shotgun_xmlrpc;
use Value;

require math;

\: deb(void; string s) { if (false) print(s); }

global int entitiesSoFar = 0;

documentation: """
Finds and returns the part of the Value tree which is the Array of entity
fields and returns it as an array of field arrays. Each member of the array
is an entity represented as an array of (name, Value) pairs -- i.e. the
fields. 
"""

class: EntityFields
{
    Field               := (string, Value);
    FieldArray          := Field[];
    EntityFieldArray    := FieldArray[];
    FieldValueArray     := (int, Value)[];
    StringFieldArray    := (int, string)[];
    FloatFieldArray     := (int, float)[];
    IntFieldArray       := (int, int)[];
    BoolFieldArray      := (int, bool)[];

    EntityFieldArray    _entities;
    int                 _idIndex;
    int                 _typeIndex;
    int                 _totalEntities;
    int                 _totalPages;
    int                 _thisPage;

    documentation: """
    The EntityFields constructor takes the Value returned form an XML-RPC
    call and converts it into an internal format. """

    method: size (int; )
    {
        return _entities.size();
    }

    method: appendEntities (void; EntityFields incoming)
    {
        for_each (ent; incoming._entities) _entities.push_back (ent);
    }

    method: EntityFields (EntityFields; Value responseValue)
    {
        let Struct [ (_, Struct top) ] = responseValue;

        _entities = EntityFieldArray();

        for_each (member; top)
        {
            if (member._0 == "entities") 
            {
                let Array list = member._1;

                for_each (entity; list) 
                {
                    let Struct fieldList = entity;
                    FieldArray fields = FieldArray();

                    for_each (f; fieldList) fields.push_back(f);
                    _entities.push_back(fields);
                }
            }
            else
            if (member._0 == "paging_info") 
            {
                let Struct s = member._1;
                for_each (p; s)
                {
                    case (p._0)
                    {
                        "page_count" -> { let Int i = p._1; _totalPages = i; }
                        "entity_count" -> { let Int i = p._1; _totalEntities = i; }
                        "current_page" -> { let Int i = p._1; _thisPage = i; }
                    }
                }
                deb ("totalPages %s totalEntities %s thisPage %s\n" % (_totalPages, _totalEntities, _thisPage));
            }

        }

        //
        //  Find special indices
        //

        let entity0 = _entities.front();

        for_index (i; entity0)
        {
            let name = entity0[i]._0;
            if (name == "id") _idIndex = i;
            if (name == "id") _typeIndex = i;
        }
    }

    documentation: """
    Finds and returns an array of tuples of the form (int,Value) which has
    the entity id as the first part of the tuple and the field Value as the
    second.""";

    method: extractField (FieldValueArray; string name)
    {
        FieldValueArray fields;
        int fieldIndex = -1;
        let entity0 = _entities.front();

        for_index (i; entity0)
        {
            let f = entity0[i];
            if (f._0 == name) fieldIndex = i;
        }

        if (fieldIndex == -1) throw exception("No field named '%s'" % name);
        
        for_each (entity; _entities) 
        {
            let Int    id = entity[_idIndex]._1,
                value     = entity[fieldIndex]._1;

            fields.push_back( (id, value) );
        }
        
        return fields;
    }

    method: extractStringField (StringFieldArray; string name)
    {
        let fields = extractField(name);
        StringFieldArray array;

        for_each (field; fields)
        {
            let (id, value) = field;
            
            case (value)
            {
                String x -> { array.push_back((id, x)); }
                Nil -> { string s = nil; array.push_back((id, s)); }
            }
        }

        return array;
    }

    method: extractIntField (IntFieldArray; string name, int nilValue = int.min)
    {
        let fields = extractField(name);
        IntFieldArray array;

        for_each (field; fields)
        {
            let (id, value) = field;
            
            case (value)
            {
                Int x       -> { array.push_back((id, x)); }
                Nil         -> { array.push_back((id, nilValue)); }
            }
        }

        return array;
    }

    method: extractFloatField (FloatFieldArray; string name, float nilValue = float.min)
    {
        let fields = extractField(name);
        FloatFieldArray array;

        for_each (field; fields)
        {
            let (id, value) = field;
            
            case (value)
            {
                Double x    -> { array.push_back((id, x)); }
                Nil         -> { array.push_back((id, nilValue)); }
            }
        }

        return array;
    }

    method: extractBoolField (BoolFieldArray; string name, bool nilValue = false)
    {
        let fields = extractField(name);
        BoolFieldArray array;

        for_each (field; fields)
        {
            let (id, value) = field;
            
            case (value)
            {
                Bool x      -> { array.push_back((id, x));}
                Nil         -> { array.push_back((id, nilValue)); }
            }
        }

        return array;
    }
}



documentation: """
ShotgunServer holds the server URL, script name and key, and any additional
state required to manage a connection to one shotgun server. The important
methods on this class are: 

    find() -- do a query to get a list of entity fields

""";

class: ShotgunServer
{
    EntityFieldsFunc := (void;EntityFields);

    string _url;
    string _script_name;
    string _script_key;
    Value  _script_struct;
    int    _serialNumber;

    method: ShotgunServer (ShotgunServer; string url, string script_name, string script_key)
    {
        _url = url;
        _script_name = script_name;
        _script_key = script_key;
        _script_struct = Struct( [ ("script_name", String(script_name) ),
                                   ("script_key", String(script_key)) ] );
    }

    method: call (void; string name, [Value] params, ReturnFunc F)
    {
        shotgun_xmlrpc.call(_url, name, _script_struct : params, F);
    }

    method: callRead (void; Value queryParam, ReturnFunc F)
    {
        call("read", [queryParam], F);
    }

    documentation: """
    find() takes the name of an entity followed by a list of strings
    indicating fields you want reported. Next is a callback function which
    takes an [Value] and returns void; this is the standard xmlrpc
    ReturnFunc type.

    Finally, you can limit the returned entities using the filters
    argument. This is a <general_condition> Struct (tree) which can have
    arbitrarily nested search terms. See apiv3.txt for more information
    about the 'read' call and the filter syntax.

    You will only receive the first numPerPage entries (default 500) if you
    don't explicity set page and numPerPage arguments.
    """;

    method: _doFind (void; 
                  string entityType,
                  [string] fields,
                  Value filters,
                  EntityFieldsFunc Fcallback,
                  int page,
                  int numPerPage,
                  EntityFields[] responses,
                  bool isRequest,
                  Value responseValue)
    {
        if (isRequest)
        //
        //  Then this is a request call, so make one request
        //
        {
            [Value] fieldList;

            let count = 0;
            for_each (f; fields) 
            {
                fieldList = String(f) : fieldList;
                ++count;
            }

            let paging = Struct( [ ("paging",
                            Struct( [("current_page", Int(page)),
                                        ("entities_per_page", Int(numPerPage))] )),
                            ("filters", filters),
                            ("type", String(entityType))
                            ] );

            if (0 != count)
            {
                paging = Struct( [ ("paging",
                            Struct( [("current_page", Int(page)),
                                        ("entities_per_page", Int(numPerPage))] )),
                            ("filters", filters),
                            ("type", String(entityType)),
                            ("return_fields", Array(fieldList))
                            ] );
            }

            callRead(paging, _doFind (entityType,
                    fields,
                    filters,
                    Fcallback,
                    page,
                    numPerPage,
                    responses,
                    false,));
        }
        else
        //
        //  This is a response call, so process fields and check to
        //  see if we have everything.  If it's the first response,
        //  send more requests if necessary.
        //
        {
            let entityFields = EntityFields(responseValue);

            let lim = entityFields._totalPages,
                hardLim = int(950/numPerPage) + 1,
                finalLim = math.min(lim, hardLim);

            if (entityFields._totalPages > 1 && responses.size() == 0)
            //
            //  Then this is first response and we need to make more
            //  requests.
            //
            {
                if (finalLim < lim)
                {
                    print ("WARNING: original request for %s %s entities limited to %s (%s pages)\n" % 
                            (entityFields._totalEntities, entityType, finalLim*numPerPage, finalLim));
                }

                for (int p = 2; p <= finalLim; ++p)
                {
                    _doFind (entityType,
                            fields,
                            filters,
                            Fcallback,
                            p,
                            numPerPage,
                            responses,
                            true,
                            Nil);
                }
            }
            responses.push_back(entityFields);
            entitiesSoFar += numPerPage;
            commands.redraw();
            deb ("response #%s of %s received\n" % (responses.size(), finalLim));

            if (finalLim == responses.size())
            //
            //  We have all responses, so merge and call callback.
            //
            {
                let all = responses[0];
                for (int p = 1; p < finalLim; ++p)
                {
                    all.appendEntities (responses[p]);
                }

                entitiesSoFar = 0;
                Fcallback (all);
            }
            commands.redraw();
        }
    }

    method: find (void; 
                  string entityType,
                  [string] fields,
                  EntityFieldsFunc Fcallback,
                  Value filters = nil,
                  int page = 1,
                  int numPerPage = 50)
    {
        let myFilters = if (filters eq nil) then Struct( [("conditions", EmptyArray), ("logical_operator", String("and"))] ) else filters;

        entitiesSoFar = 0;
        _doFind (entityType,
                fields,
                myFilters,
                Fcallback,
                page,
                numPerPage,
                EntityFields[](),
                true,
                Nil);
    }

    method: __test (void;)
    {
        \: printValues (void; EntityFields fields)
        {
            let codes = fields.extractStringField("code"),
                descriptions = fields.extractStringField("description"),
                in = fields.extractIntField("sg_cut_in"),
                out = fields.extractIntField("sg_cut_out");

            for_index (i; codes)
            {
                print("shot \"%s\" id=%d (%s) [%d - %d]\n" % (codes[i]._1, 
                                                              codes[i]._0,
                                                              descriptions[i]._1,
                                                              in[i]._1,
                                                              out[i]._1));
            }
        }
        
        find("Shot", 
             ["code", "created_by", "description", "cut_in", "sg_cut_in", "sg_cut_out"],
             printValues,
             Struct( [("conditions", 
                       EmptyArray),
//                          Array ([ Struct ( [ ("path", String("code")), 
//                                              ("relation", String("contains")),
//                                              ("values", Array ([ String("2") ])) 
//                                              ] )
//                                  ])),
                       ("logical_operator", String("and"))] )
             );
    }
}

}
