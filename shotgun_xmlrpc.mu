
documentation: """
The xmlrpc module implements XML-RPC (remote procedure call via a web
server using XML to hold parameter data structres). The main entry
point is the call() function. You will need to know how to create a
xmlrpc.Value tree in order to create parameter values.
""";

module: shotgun_xmlrpc {
use io;
use encoding;
require math;
require commands;

documentation: """
The Value union is a tree data structure which can hold an arbitrary
XML-RPC value. Each parameter to the call() function is a Value true. The
RPC will result in a single Value.
""";

union: Value
{
      Nil           // appears to be common
    | ErrorValue    // internal error
    | Int int 
    | String string 
    | Bool bool 
    | Double float 
    | DateTime (int,int,int,int,int,int)
    | Binary byte[]
    | Struct [(string, Value)]
    | EmptyArray
    | Array [Value]
}

ReturnFunc := (void; Value);

class: ResponseValue
{
    bool fault;
    Value value;
}

function: reverse ([Value]; [Value] a)
{
    [Value] n;
    for_each (p; a) n = p : n;
    n;
}

function: reverse ([(string, Value)]; [(string, Value)] a)
{
    [(string, Value)] n;
    for_each (p; a) n = p : n;
    n;
}

function: posixRegex (regex; string pattern)
{
    if (runtime.build_os() == "WINDOWS") return regex(pattern, 16);
    else                                 return regex(pattern);
}

function: outputValue (void; ostream o, Value v)
{
    print(o, "<value>");

    case (v)
    {
        Nil         -> { print(o, "</nil>"); }
        Int i       -> { print(o, "<int>%d</int>" % i); }
        String s    -> { print(o, "<string>%s</string>" % s); }
        Bool b      -> { print(o, "<boolean>%d</boolean>" % (if b then 1 else 0)); }
        Double f    -> { print(o, "<double>%g</double>" % f); }
        EmptyArray  -> { print(o, "<array><data></data></array>"); }
        DateTime d  -> { print(o, "<dateTime.iso8601>%04d-%02d-%02dT%02d:%02d:%02d</dateTime.iso8601>" % d); }

        Struct s -> 
        { 
            print(o, "<struct>");

            for_each (p; s) 
            {
                print(o, "<member><name>%s</name>" % p._0);
                outputValue(o, p._1);
                print(o, "</member>");
            }

            print(o, "</struct>");
        }

        Array a ->
        {
            print(o, "<array><data>");
            for_each (e; a) outputValue(o, e);
            print(o, "</data></array>");
        }

        Binary b -> 
        {
            print(o, "<base64>");
            print(o, utf8_to_string(to_base64(b)));
            print(o, "</base64>");
        }
    }

    print(o, "</value>");
}

function: outputParamList (void; ostream o, [Value] vlist)
{
    print(o, "<params>");

    for_each (v; vlist)
    {
        print(o, "<param>");
        outputValue(o, v);
        print(o, "</param>");
    }

    print(o, "</params>");
}

function: outputMethod (void; ostream o, string methodName, [Value] paramList)
{
    print(o, "<?xml version=\"1.0\"?>");
    print(o, "<methodCall><methodName>%s</methodName>" % methodName);
    outputParamList(o, paramList);
    print(o, "</methodCall>");
}

function: elementSplit (string[]; string instring)
{
    use encoding;
    let barray = string_to_utf8(instring);
    string[] array;
    byte[] temp;

    for (int i = 0, is = barray.size(), i0 = 0, i1 = 0; i < is; i = i1)
    {
        for (i0 = i; i0 < is; i0++)
        {
            temp.push_back(barray[i0]);
            if (barray[i0] == byte('>')) break;
        }

        for (i1 = i0 + 1; i1 < is; i1++)
        {
            let b = barray[i1];
            if (b != byte(' ') && b != byte('\n') && b != byte('\r')) break;
        }

        if (i1 < is && barray[i1] == byte('<'))
        {
            let str = utf8_to_string(temp),
                same = false;
            if (!array.empty())
            {
                let last = array.back(),
                    len = math.min(last.size(), str.size());

                if (len > 2 && str[1] == '/') 
                {
                    same = true;
                    for (int j = 2; j < len && same == true; ++j)
                    {
                        if (last[j-1] != str[j]) same = false;
                    }
                }
            }
            if (same) array.back() = array.back()+str;
            else array.push_back(str);
            temp.clear();
        }
        else
        {
            for (int q = i0 + 1; q < i1 && q < is; q++)
            {
                temp.push_back(barray[q]);
            }
        }
    }

    if (!temp.empty()) array.push_back(utf8_to_string(temp));

    array;
}

function: parseResult (Value; string xml)
{
    use Value;
    
    class: ParseState
    {
        int index;
        string[] lines;

        method: next (void;) { index++; }
        method: line (string;) { lines[index]; }

        method: ensure (void; string value)
        {
            if (line() != value)
            {
                string msg = "XML parsing error: saw %s but expected %s\n" % (line(), value);
                print("ERROR: %s\n" % msg);
                throw exception(msg);
            }
        }

        method: nextIf (void; string value) { ensure(value); next(); }
    }

    /*
    let re    = regex(">[\\t\\r\\n ]*<"),
        lines = re.replace(xml, ">\b<").split("\b"); // funky
    */
    let lines = elementSplit (xml);


    \: parseStruct (Value; ParseState state) 
    { 
        state.nextIf("<struct>");
        [(string, Value)] members;

        while (state.line() != "</struct>")
        {
            state.nextIf("<member>");
            let re = posixRegex("<name>([^<]+)"),
                name = re.smatch(state.line())[1];

            state.next();
            members = (name, parseValue(state)) : members;
            state.nextIf("</member>");
        }

        state.nextIf("</struct>");
        return Struct(reverse(members));
    }

    \: parseArray (Value; ParseState state) 
    { 
        state.nextIf("<array>");
        [Value] list = nil;

        //
        //  Allow for mal-formed xml from shotgun.
        //
        if (state.line() == "<data/>") state.next();
        else
        { 
            state.nextIf("<data>");

            while (state.line() != "</data>")
            {
                list = parseValue(state) : list;
            }
            state.nextIf("</data>");
        }
        state.nextIf("</array>");

        if (list eq nil) return EmptyArray;

        return Array(reverse(list));
    }

    \: parseValue (Value; ParseState state)
    {
        let skipClosingValue = posixRegex("^<double>").match(state.line());
        if (!skipClosingValue) state.nextIf("<value>");

        string line = state.line();
        Value value = ErrorValue;

        case (line)
        {
            "<struct>"  -> { value = parseStruct(state); }
            "<array>"   -> { value = parseArray(state); }
            "<nil/>"    -> { value = Nil; state.next(); }

            _ ->
            {
                //
                //  Scalar tags
                //

                let re     = posixRegex("(<[^>]+>).*(</[^>]+>)"),
                    parts  = re.smatch(line),
                    start  = parts[1],
                    end    = parts[2];
                let re2    = posixRegex("<[^>]+>([^<]*)</[^>]+>"),
                    parts2 = re2.smatch(line),
                    body   = parts2[1];

                case (start)
                {
                    "<i4>"      -> { value = Int(int(body)); }
                    "<int>"     -> { value = Int(int(body)); }
                    "<string>"  -> { value = String(body); }
                    "<boolean>" -> { value = Bool(int(body) == 1); }
                    "<double>"  -> { value = Double(float(body)); }

                    "<dateTime.iso8601>" ->
                    {
                        let dre = posixRegex("([0-9]{4})-?([0-9]{2})-?([0-9]{2})[Tt]([0-9]{2}):([0-9]{2}):([0-9]{2})"),
                            d = dre.smatch(body);

                        assert(d.size() == 7);
                        
                        value = DateTime((int(d[1]), int(d[2]), int(d[3]),
                                          int(d[4]), int(d[5]), int(d[6])));
                    }

                    "<base64>" ->
                    {
                        value = Binary(from_base64(string_to_utf8(body)));
                    }

                    _ ->
                    {
                        throw exception("XML parser failure in shotgun_xmlrpc: unknown tag %s" % start);
                    }
                }

                state.next();
            }
        }

        if (!skipClosingValue) state.nextIf("</value>");
        return value;
    }

    \: parseParam (Value; ParseState state)
    {
        state.nextIf("<param>");
        let v = parseValue(state);
        state.nextIf("</param>");

        return v;
    }

    //
    //  Top level
    //

    for_index (i; lines)
    {
        let line = lines[i];

        if (line == "<fault>") 
        {
            let Struct [ (_, Int code), (_, String why) ] = parseValue(ParseState(i+1, lines));
            print("ERROR: XML-RPC: faultCode=%d -- %s\n" % (code, why));
            break;
        }

        if (line == "<params>") return parseParam(ParseState(i+1, lines));
    }

    return Nil;
}

global (int,float)[] inFlight;

function: addInFlight(int hash)
{
    inFlight.push_back((hash, commands.theTime()));
}

function: removeInFlight(int hash)
{
    let newList = (int,float)[]();
    for_index (i; inFlight)
    {
        if (inFlight[i]._0 != hash) newList.push_back(inFlight[i]);
    }
    inFlight = newList;
    /*
    XXX
    should be able to do the below.  the fact that we can't indicates a bug in mu, i think.
    let index = -1;
    for_index(i; inFlight) 
    {
        print ("******************     i %s\n" % i);
        print ("******************     tuple %s\n" % string(inFlight[i]));
        if (inFlight[i]._0 == hash) index = i;
    }
    if (index != -1) inFlight.erase(index,1);
    */
}

function: inFlightStats((int, float); )
{
    if (inFlight.size() != 0) return (inFlight.size(), inFlight.back()._1);
    else return (0, 0.0);
}

documentation: """
call() takes the url of the server, the name of the method to call, a list
of Value trees for the parameters, and a function to call with the result
when it is available.

call() will return immediately. The rvalFunc will be called at some later
point.
""";


function: call (void; 
                string url,
                string name,
                [Value] params,
                ReturnFunc rvalFunc)
{
    use commands;
    use app_utils;
    let str = osstream();
    outputMethod(str, name, params);

    let xml    = string(str),
        hash   = string.hash(xml + url + name + string(theTime())),
        revent = "shotgun_xmlrpc-%s-return" % hash,
        aevent = "shotgun_xmlrpc-%s-authenticate" % hash,
        eevent = "shotgun_xmlrpc-%s-error" % hash;

    \: returnFunc (void; Event event)
    {
        //print("DEBUG: XML-RCP: Returned\n");
        for_each (event; [revent, aevent, eevent]) unbind(event);
        use Value;

        removeInFlight(hash);

        Value v = ErrorValue;

        try
        {
            v = parseResult(event.contents()); 
        }
        catch (exception exc)
        {
            print("ERROR: XML-RPC: Parsing Failed: %s\n" % exc);
            print("DEBUG: url = %s\n" % url);
            print("DEBUG: name = %s\n" % name);
            print("DEBUG: params = %s\n" % params);
            print("DEBUG: Value = %s\n" % v);
            print("DEBUG: XML = %s\n" % event.contents());
        }

        try
        {
            rvalFunc(v);
        }
        catch (...) { ; }
    }

    \: errorFunc (void; Event event)
    {
        for_each (event; [revent, aevent, eevent]) unbind(event);
        removeInFlight(hash);
        throw exception("ERROR: XMP-RPC: method \"%s\"" % name);
    }

    \: authenticateFunc (void; Event event)
    {
        for_each (event; [revent, aevent, eevent]) unbind(event);
        throw exception("ERROR: XMP-RPC: method \"%s\" authentication not implementated" % name);
    }

    bind(revent, returnFunc);
    bind(aevent, authenticateFunc);
    bind(eevent, errorFunc);

    addInFlight(hash);
    //print("DEBUG: XML-RCP: Sending\n");
    httpPost(url,
             [("Content-Type", "text/xml")],
             xml,
             revent, aevent, eevent,
             true /* ignoreSslErrors */);
}

\: test (void;)
{
    use Value;
    
    let p1   = Struct( [ ("script_name", String("rv") ),
                         ("script_key", String("4b1676497a208c845b12f5c6734daf9d6e7c6274")) ] );

    let p2   = Struct( [ ("paging", 
                          Struct( [("current_page", Int(1)),
                                   ("entities_per_page", Int(500))] )),
                         ("filters", 
                          Struct( [("conditions", EmptyArray),
                                   ("logical_operator", String("and"))] )),
                         ("type", String("Shot"))
                         ] );

    \: F (void; Value v)
    {
        print("F = %s\n" % v);
    }

    call("https://tweak.shotgunstudio.com/api3_preview/", "read", [p1, p2], F);
}

} // module shotgun_xmlrpc
