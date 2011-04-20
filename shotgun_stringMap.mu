
module: shotgun_stringMap
{

    global int[] primes = 
        { 7, 13, 23, 53, 97, 193, 389, 769, 1543, 3079, 6151, 12289, 24593,
          49157, 98317, 196613, 393241, 786433, 1572869, 3145739, 6291469, 
          12582917, 25165843 };

    \: nextPrime (int; int p)
    {
        for_index (i; primes) if (primes[i] > p) return primes[i];
        return primes.back();
    }

    \: hash (string key) { string(key).hash(); }

    documentation: """
    A basic hash map which uses a string as the index. The hash
    is created by using the string.hash() function.
    """;

    class: StringMap
    {
        class: Item
        {
            string key;
            string value;
            Item   next;
        }

        Item[] _table;
        int _numItems;

        method: keys (string[];)
        {
            string[] keyarray;

            for_each (item; _table)
            {
                for (Item i = item; i neq nil; i = i.next)
                {
                    keyarray.push_back(i.key);
                }
            }
            keyarray;
        }

        method: find (string; string key, bool noThrow = false)
        {
            let i = hash(key) % _table.size();

            for (Item x = _table[i]; x neq nil; x = x.next)
            {
                if (x.key == key)
                {
                    return x.value;
                }
            }
            if (noThrow) return nil;

            throw exception ("No key '%s' in StringMap" % key);
        }

        method: toString(string; string indent="    ")
        {
            string out = "%d keys: \n" % _numItems;
            for_each (k; keys())
            {
                out = out + ("%s%s -> %s\n" % (indent, k, find(k)));
            }
            return out;
        }

        method: toStringArray(string[]; )
        {
            string[] out;
            for_each (k; keys())
            {
                out.push_back (k);
                out.push_back (find(k));
            }
            return out;
        }

        method: _addInternal (void; string key, string value)
        {
            //  print ("_addInternal %s %s\n" % (key, value));
            let i = hash(key) % _table.size();

            for (Item x = _table[i]; x neq nil; x = x.next)
            {
                if (x.key == key)
                {
                    x.value = value;
                    return;
                }
            }
            //  key not found
            _table[i] = Item(key, value, _table[i]);
            _numItems++;
        }

        method: resize (void;)
        {
            let newSize = nextPrime(_table.size()),
                oldTable = _table;

            _table = Item[]();
            _table.resize(newSize);

            for_each (item; oldTable)
            {
                for (Item i = item; i neq nil; i = i.next)
                {
                    _addInternal(i.key, i.value);
                }
            }
        }

        method: StringMap (StringMap; int initialSize)
        {
            _table = Item[]();
            _table.resize(nextPrime(initialSize));
            resize();
        }

        method: StringMap (StringMap; string[] data)
        {
            _table = Item[]();
            _table.resize(nextPrime(data.size()/2));
            resize();
            if ((data.size() % 2) != 0)
            {
                throw exception ("ERROR: stringMap data has odd length\n");
            }
            else
            {
                for (int i = 0; i < data.size(); i += 2)
                {
                    add (data[i], data[i+1]);
                }
            }
        }

        method: add (void; string key, string value)
        {
            _addInternal(key, value);
            if (_numItems > _table.size() * 2) resize();
        }

        method: fieldEmpty (bool; string key)
        {
            let s = find (key, true);
            return (s eq nil || s == "");
        }

        method: findString (string; string key)
        {
            string s = find(key);
            if (s eq nil) throw exception ("String value for key '%s' is not set in StringMap" % key);
            return s;
        }

        method: findBool (bool; string key)
        {
            string s = find(key);
            if (s eq nil) throw exception ("Bool value for key '%s' is not set in StringMap" % key);
            return bool(s);
        }

        method: findInt (int; string key)
        {
            string s = find(key);
            if (s eq nil) throw exception ("Int value for key '%s' is not set in StringMap" % key);
            return int(s);
        }

        method: findFloat (float; string key)
        {
            string s = find(key);
            if (s eq nil) throw exception ("Float value for key '%s' is not set in StringMap" % key);
            return float(s);
        }
    }
}

