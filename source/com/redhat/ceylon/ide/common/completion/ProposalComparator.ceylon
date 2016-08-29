import com.redhat.ceylon.ide.common.util {
    RequiredType,
    types
}
import com.redhat.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    ModelUtil {
        isNameMatching
    }
}

import java.util {
    Comparator
}

class ProposalComparator(String prefix, RequiredType required)
        satisfies Comparator<DeclarationWithProximity> {

    shared actual Integer compare(x, y) {

        DeclarationWithProximity x;
        DeclarationWithProximity y;

        if (x===y) {
            return 0;
        }

        try {

            //variable Boolean xbt = x.declaration is NothingType;
            //variable Boolean ybt = y.declaration is NothingType;
            //if (xbt, ybt) {
            //    return 0;
            //}
            //if (xbt, !ybt) {
            //    return 1;
            //}
            //if (ybt, !xbt) {
            //    return -1;
            //}

            String xName = x.name;
            String yName = y.name;
            Boolean yUpperCase
                    = yName.first?.uppercase
                    else false;
            Boolean xUpperCase
                    = xName.first?.uppercase
                    else false;
            if (!prefix.empty) {
                //proposals which match the case of the
                //typed prefix first
                Boolean upperCasePrefix
                        = prefix.first?.uppercase
                        else false;
                if (!xUpperCase, yUpperCase) {
                    return if (upperCasePrefix) then 1 else -1;
                }
                else if (xUpperCase, !yUpperCase) {
                    return if (upperCasePrefix) then -1 else 1;
                }
            }
            
            value xd = x.declaration;
            value yd = y.declaration;
            if (exists requiredType = required.type) {
                value xtype = types.getResultType(xd);
                value ytype = types.getResultType(yd);
                Boolean xassigns
                        = xtype?.isSubtypeOf(requiredType)
                        else false;
                Boolean yassigns
                        = ytype?.isSubtypeOf(requiredType)
                        else false;
                if (xassigns && !yassigns) {
                    return -1;
                }
                else if (yassigns && !xassigns) {
                    return 1;
                }
                if (xassigns, yassigns) {
                    //both are assignable - prefer the
                    //one which isn't assignable to
                    //everything
                    Boolean xbottom = xtype?.nothing else false;
                    Boolean ybottom = ytype?.nothing else false;
                    if (xbottom, !ybottom) {
                        return 1;
                    }
                    else if (ybottom, !xbottom) {
                        return -1;
                    }
                }
            }
            
            value xdepr = xd.deprecated;
            value ydepr = yd.deprecated;
            if (xdepr && !ydepr) {
                return 1;
            }
            else if (!xdepr && ydepr) {
                return -1;
            }

            switch(x.proximity<=>y.proximity)
            case (equal) {}
            case (larger) {
                return 1;
            }
            case (smaller) {
                return -1;
            }
            
            if (exists requiredName = required.parameterName) {
                Boolean xnr = isNameMatching(xName, requiredName);
                Boolean ynr = isNameMatching(yName, requiredName);
                if (xnr && !ynr) {
                    return -1;
                }
                else if (!xnr && ynr) {
                    return 1;
                }
            }

            //lowercase proposals first if no prefix
            if (!xUpperCase, yUpperCase) {
                return -1;
            }
            else if (xUpperCase, !yUpperCase) {
                return 1;
            }
            
            //sort by unqualified name
            switch (xName<=>yName)
            case (equal) {}
            case (larger) {
                return 1;
            }
            case (smaller) {
                return -1;
            }

            //if all else fails sort by qualified name
            String xqn = xd.qualifiedNameString;
            String yqn = yd.qualifiedNameString;
            return switch (xqn<=>yqn) 
                case (larger) 1
                case (smaller) -1
                case (equal) 0;
        }
        catch (e) {
            e.printStackTrace();
            return 0;
        }
    }
   
    shared actual Boolean equals(Object that) {
        if (is ProposalComparator that) {
            return prefix==that.prefix;
        }
        else {
            return false;
        }
    }

    shared actual Integer hash {
        variable value hash = 1;
        hash = 31*hash + prefix.hash;
        return hash;
    }
}
