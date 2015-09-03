import java.util {
    Comparator
}
import com.redhat.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    NothingType,
    Type,
    TypedDeclaration
}
import com.redhat.ceylon.ide.common.util {
    types
}

class ProposalComparator(String prefix, Type? type) satisfies Comparator<DeclarationWithProximity> {

    shared actual Integer compare(DeclarationWithProximity x, DeclarationWithProximity y) {
        try {
            variable Boolean xbt = x.declaration is NothingType;
            variable Boolean ybt = y.declaration is NothingType;
            if (xbt, ybt) {
                return 0;
            }
            if (xbt, !ybt) {
                return 1;
            }
            if (ybt, !xbt) {
                return -1;
            }
            Type? xtype = types.getResultType(x.declaration);
            Type? ytype = types.getResultType(y.declaration);
            Boolean xbottom = xtype?.nothing else false;
            Boolean ybottom = ytype?.nothing else false;
            if (xbottom, !ybottom) {
                return 1;
            }
            if (ybottom, !xbottom) {
                return -1;
            }
            String xName = x.name;
            String yName = y.name;
            Boolean yUpperCase = yName.first?.uppercase else false;
            Boolean xUpperCase = xName.first?.uppercase else false;
            if (!prefix.empty) {
                Boolean upperCasePrefix = prefix.first?.uppercase else false;
                if (!xUpperCase, yUpperCase) {
                    return if (upperCasePrefix) then 1 else -1;
                } else if (xUpperCase, !yUpperCase) {
                    return if (upperCasePrefix) then -1 else 1;
                }
            }
            if (exists type) {
                Boolean xassigns = xtype?.isSubtypeOf(type) else false;
                Boolean yassigns = ytype?.isSubtypeOf(type) else false;
                if (xassigns, !yassigns) {
                    return -1;
                }
                if (yassigns, !xassigns) {
                    return 1;
                }
                if (xassigns, yassigns) {
                    Boolean xtd = x.declaration is TypedDeclaration;
                    Boolean ytd = y.declaration is TypedDeclaration;
                    if (xtd, !ytd) {
                        return -1;
                    }
                    if (ytd, !xtd) {
                        return 1;
                    }
                }
            }
            if (x.proximity != y.proximity) {
                return comparisonToInt(Integer(x.proximity).compare(y.proximity));
            }
            if (!xUpperCase, yUpperCase) {
                return -1;
            } else if (xUpperCase, !yUpperCase) {
                return 1;
            }
            Integer nc = comparisonToInt(xName.compare(yName));
            if (nc == 0) {
                variable String xqn = x.declaration.qualifiedNameString;
                variable String yqn = y.declaration.qualifiedNameString;
                return comparisonToInt(xqn.compare(yqn));
            } else {
                return nc;
            }
        } catch (Exception e) {
            e.printStackTrace();
            return 0;
        }
    }
    
    Integer comparisonToInt(Comparison c) {
        return switch (c)
        case (smaller) -1
        case (equal) 0
        case (larger) 1;
    }
    
    shared actual Boolean equals(Object that) {
        if (is ProposalComparator that) {
            return prefix==that.prefix;
        }
        else {
            return false;
        }
    }
}
