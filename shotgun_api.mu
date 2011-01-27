
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

/* Example Use */

/*

ShotgunServer sg = ShotgunServer(URL, SCRIPT, KEY);

\: deleteCB(void; bool ret) {
    print("DEBUG: DELETED: %s\n" % ret);
}

\: updateCB(void; EntityFields fields) {
    let descriptions = fields.extractStringField("description"),
        ids = fields.extractIntField("id");
    print("DEBUG: DESCRIPTIONS: %s\n" % descriptions);
    print("DEBUG: IDS: %s\n" % ids);
    sg.delete("Playlist", ids[0]._1, deleteCB);
}

\: createCB(void; EntityFields fields) {
    let descriptions = fields.extractStringField("description"),
        ids = fields.extractIntField("id");
    print("DEBUG: DESCRIPTIONS: %s\n" % descriptions);
    print("DEBUG: IDS: %s\n" % ids);
    let data = Struct([("description", String("description part two"))]);
    sg.update("Playlist", ids[0]._1, data, updateCB);
}

let data = Struct([("description", String("this is a description")),
                   ("code", String("Test")),
                   ("project", Struct([
                            ("type", String("Project")),
                            ("id", Int(106)),
                           ]))
           ]);

sg.create("Playlist", data, nil, createCB);

\: batchCB(void; Value responses) {
    print("DEBUG: RESPONSES: %s\n" % responses);
}

let requests = Array([
    Struct([
        ("request_type", String("create")),
        ("entity_type", String("Playlist")),
        ("data", Struct([
                    ("code", String("Test 1")),
                    ("project", Struct([
                             ("type", String("Project")),
                             ("id", Int(106)),
                            ]))
                 ])),
    ])]);

sg.batch(requests, batchCB);

*/

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
            else
            if (member._0 == "id")
            {
                // No paging, entity returned directly
                FieldArray fields = FieldArray();
                for_each (f; top) fields.push_back(f);
                _entities.push_back(fields);
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
    BoolFunc := (void; bool);
    ValueFunc := (void; Value);

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

    method: _convertStructToFields(Value; Value v) {
        // convert data into a list of {"field_name": field, "value": value} structs
        let Struct s = v;
        [Value] fields;
        for_each(p; s)
            fields = Struct([("field_name", String(p._0)), ("value", p._1)]) : fields;
        return Array(fields);
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
                  Value order,
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

            let parts = [("paging", Struct([
                                        ("current_page", Int(page)),
                                        ("entities_per_page", Int(numPerPage))])),
                         ("filters", filters),
                         ("type", String(entityType))];
            if (0 != count)
                parts = ("return_fields", Array(fieldList)) : parts;
            if (order neq nil)
                parts = ("sorts", order) : parts;

            callRead(Struct(parts), _doFind (entityType,
                    fields,
                    filters,
                    Fcallback,
                    page,
                    numPerPage,
                    order,
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
                            order,
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
                  int numPerPage = 50,
                  Value order = nil)
    {
        let myFilters = if (filters eq nil) then Struct( [("conditions", EmptyArray), ("logical_operator", String("and"))] ) else filters;

        entitiesSoFar = 0;
        _doFind (entityType,
                fields,
                myFilters,
                Fcallback,
                page,
                numPerPage,
                order,
                EntityFields[](),
                true,
                Nil);
    }

    method: create (void; string entityType, Value data, [string] fields, EntityFieldsFunc Fcallback) {
        // convert fields into xmlrpc friendly Values
        [Value] fieldList;
        for_each(f; fields)
            fieldList = String(f) : fieldList;
        // build the actual xmlrpc argument
        let args = Struct([
                        ("type", String(entityType)),
                        ("fields", _convertStructToFields(data)),
                        ("return_fields", if(fields neq nil) then Array(fieldList) else Array([String("id")])),
                    ]);
        // callback for response
        \: _handleCreateResponse(void; Value responseValue) {
            deb("_handleCreateResponse called: %s\n" % responseValue);
            Fcallback(EntityFields(responseValue));
            commands.redraw();
        }
        // do the call
        call("create", [args], _handleCreateResponse);
    }

    method: update(void; string entityType, int entityId, Value data, EntityFieldsFunc Fcallback) {
        let args = Struct([
                        ("type", String(entityType)),
                        ("id", Int(entityId)),
                        ("fields", _convertStructToFields(data)),
                   ]);
        // callback for response
        \: _handleUpdateResponse(void; Value responseValue) {
            deb("_handleUpdateResponse called: %s\n" % responseValue);
            Fcallback(EntityFields(responseValue));
            commands.redraw();
        }
        // do the call
        call("update", [args], _handleUpdateResponse);
    }

    method: delete(void; string entityType, int entityId, BoolFunc Fcallback) {
        let args = Struct([
                        ("type", String(entityType)),
                        ("id", Int(entityId)),
                   ]);
        // callback for response
        \: _handleDeleteResponse(void; Value responseValue) {
            deb("_handleDeleteResponse called: %s\n" % responseValue);
            let Struct [ (_, Bool ret) ] = responseValue;
            Fcallback(ret);
            commands.redraw();
        }
        // do the call
        call("delete", [args], _handleDeleteResponse);
    }

    method: batch(void; Value requests, ValueFunc Fcallback) {
        [Value] myRequests;
        case(requests) {
            Array a -> {
                for_each(p; a) {
                    let Struct request = p;
                    string requestType;
                    Value entityType;
                    Value entityId;
                    Value data;
                    Value returnFields;
                    for_each(q; request) {
                        case(q._0) {
                            "request_type" -> { let String temp = q._1; requestType = temp;}
                            "entity_type" -> { entityType = q._1; }
                            "entity_id" -> { entityId = q._1; }
                            "data" -> { data = q._1; }
                            "returnFields" -> { returnFields = q._1; }
                        }
                    } // end for_each(q, request)

                    case(requestType) {
                        "create" -> {
                            let parts = [("request_type", String("create")),
                                         ("type", entityType),
                                         ("fields", _convertStructToFields(data))];
                            if(returnFields neq nil)
                                parts = ("return_fields", returnFields) : parts;
                            myRequests = Struct(parts) : myRequests;
                        } "update" -> {
                            let arg = Struct([
                                        ("request_type", String("update")),
                                        ("type", entityType),
                                        ("id", entityId),
                                        ("fields", _convertStructToFields(data))]);
                            myRequests = arg : myRequests;
                        } "delete" -> {
                            let arg = Struct([
                                        ("request_type", String("delete")),
                                        ("type", entityType),
                                        ("id", entityId)]);
                            myRequests = arg : myRequests;
                        }
                    } // end requestType case
                } // end for_each(p, a)
            } // end case Array a
        } // end case(requests)
        // callback for response
        \: _handleBatchResponse(void; Value responseValue) {
            deb("_handleBatchResponse called: %s\n" % responseValue);
            // START HERE: Need a different callback type for batch returns
            Fcallback(responseValue);
            commands.redraw();
        }
        // do the call
        call("batch", [Array(myRequests)], _handleBatchResponse);
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
