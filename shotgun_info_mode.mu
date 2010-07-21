
//
//  Custom Heads-Up Display Widget
//  Shotgun Info
//

module: shotgun_info_mode {
use rvtypes;
use glyph;
use app_utils;
use math;
use math_util;
use commands;
use extra_commands;
use gl;
use glu;
require io;
require shotgun_fields;
require shotgun_stringMap;
require system;

StringMap := shotgun_stringMap.StringMap;

//----------------------------------------------------------------------
//
//

class: ShotgunInfo : Widget
{
    method: ShotgunInfo (ShotgunInfo; string name)
    {
        this.init(name,
                  [ ("pointer-1--push", storeDownPoint(this,), "Move Shotgun Info"),
                    ("pointer-1--drag", drag(this,), "Move Shotgun Info"),
                    ("pointer-1--release", release(this, , nil), ""),
                    ("pointer--move", move(this,), "") ],
                  false);

        _x = 40;
        _y = 60;

        this.toggle();
    }

    method: render (void; Event event)
    {
        State state = data();

        let pinfo   = state.pixelInfo,
            iname   = if (pinfo neq nil && !pinfo.empty()) 
                         then pinfo.front().name
                         else nil;

        let domain  = event.domain(),
            bg      = state.config.bg,
            fg      = state.config.fg,
            err     = isCurrentFrameError();

        //  print ("%s\n" % system.time());

        (string,string)[]   attrs;

        try
        {
            let sourceNum = int (regex.smatch("[a-zA-Z]+([0-9]+)", iname).back());
            if ("updating" == shotgun_fields.infoStatusFromSource (sourceNum))
            {
                attrs.push_back (("", "  Updating ..."));
            }
            else
            {
                StringMap info = shotgun_fields.infoFromSource (sourceNum);

                let keys = shotgun_fields.displayOrder();
                for (int i = keys.size()-1; i >= 0; --i)
                {
                    string k = keys[i];
                    try
                    {
                        string v = info.find(k);
                        if (v neq nil && v != "")
                        {
                            let pn = shotgun_fields.prettyNameMap.find(k),
                                    t = shotgun_fields.fieldTypeMap.find(k);

                            if ("entity" == t)
                            {
                                let (name, _, _) = shotgun_fields.extractEntityValueParts(v);
                                v = name;
                            }
                            if (v neq nil) attrs.push_back ((pn, v));
                        }
                    }
                    catch (...)
                    {
                        attrs.push_back((k, "ERROR: config displayOrder() or fieldDescriptors()"));
                    }
                }
            }
        }
        catch(object obj) 
        {
            //  print ("exception %s\n" % string(obj));
            attrs.resize(0);
            attrs.push_back (("", "  No Shotgun info for this source"));
        }
        //  print ("%s\n" % attrs);

        gltext.size(state.config.infoTextSize);
        setupProjection(domain.x, domain.y);

        let margin  = state.config.bevelMargin;
        let x       = _x + margin;
        let y       = _y + margin;
        let blah = expandNameValuePairs(attrs);
        let tbox    = drawNameValuePairs(blah, fg, bg, x, y, margin)._0;
        let emin    = vec2f(_x, _y);
        let emax    = emin + tbox + vec2f(margin*2.0, 0.0);

        if (_inCloseArea)
        {
            drawCloseButton(x - margin/2,
                            tbox.y + y - margin - margin/4,
                            margin/2, bg, fg);
        }

        this.updateBounds(emin, emax);
    }
}

\: createMode (Mode;)
{
    return ShotgunInfo("ShotgunInfo");
}

\: theMode (ShotgunInfo; )
{
    ShotgunInfo m = rvui.minorModeFromName("ShotgunInfo");

    return m;
}

}
