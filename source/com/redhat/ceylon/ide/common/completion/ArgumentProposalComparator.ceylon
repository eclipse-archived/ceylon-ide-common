import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    ModelUtil
}

import java.util {
    Comparator
}

class ArgumentProposalComparator(String? exactName) satisfies Comparator<DeclarationWithProximity> {
    
    shared actual Integer compare(DeclarationWithProximity x, DeclarationWithProximity y) {
        value xname = x.name;
        value yname = y.name;
        if (exists exactName) {
            variable value xhit = xname.equals(exactName);
            variable value yhit = yname.equals(exactName);
            if (xhit, !yhit) {
                return -1;
            }
            if (yhit, !xhit) {
                return 1;
            }
            xhit = ModelUtil.isNameMatching(xname, exactName);
            yhit = ModelUtil.isNameMatching(yname, exactName);
            if (xhit, !yhit) {
                return -1;
            }
            if (yhit, !xhit) {
                return 1;
            }
        }
        value xd = x.declaration;
        value yd = y.declaration;
        value xdepr = xd.deprecated;
        value ydepr = yd.deprecated;
        if (xdepr, !ydepr) {
            return 1;
        }
        if (!xdepr, ydepr) {
            return -1;
        }
        value xp = x.proximity;
        value yp = y.proximity;
        value p = xp - yp;
        if (p != 0) {
            return p;
        }
        value c = javaString(xname).compareTo(yname);
        if (c != 0) {
            return c;
        }
        return javaString(xd.qualifiedNameString)
                .compareTo(yd.qualifiedNameString);
    }
    
    shared actual Boolean equals(Object that) => false;
}