import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    ParameterList,
    Value
}
import java.util {
    List,
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable
}

Boolean isLocation(OccurrenceLocation? loc1, OccurrenceLocation loc2) {
    if (exists loc1) {
        return loc1 == loc2;
    }
    return false;
}

// see CompletionUtil.getParameters
List<Parameter> getParameters(ParameterList pl,
    Boolean includeDefaults, Boolean namedInvocation) {
    List<Parameter> ps = pl.parameters;
    if (includeDefaults) {
        return ps;
    }
    else {
        List<Parameter> list = ArrayList<Parameter>();
        for (p in CeylonIterable(ps)) {
            if (!p.defaulted || 
                (namedInvocation && 
                p==ps.get(ps.size()-1) && 
                    p.model is Value &&
                    p.type exists &&
                    p.declaration.unit
                    .isIterableParameterType(p.type))) {
                list.add(p);
            }
        }
        return list;
    }
}
