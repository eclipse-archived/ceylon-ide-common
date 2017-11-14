/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.model.typechecker.model {
    DeclarationWithProximity,
    ModelUtil {
        isNameMatching
    }
}

import java.util {
    Comparator
}

class ArgumentProposalComparator(String? exactName)
        satisfies Comparator<DeclarationWithProximity> {
    
    shared actual Integer compare(x, y) {

        DeclarationWithProximity y;
        DeclarationWithProximity x;

        if (x===y) {
            return 0;
        }

        value xname = x.name;
        value yname = y.name;
        if (exists exactName) {
            value xExactHit = xname==exactName;
            value yExactHit = yname==exactName;
            if (xExactHit, !yExactHit) {
                return -1;
            }
            if (yExactHit, !xExactHit) {
                return 1;
            }
            value xhit = isNameMatching(xname, exactName);
            value yhit = isNameMatching(yname, exactName);
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

        switch (xname <=> yname)
        case (smaller) {
            return -1;
        }
        case (larger) {
            return 1;
        }
        else {
            value xqn = xd.qualifiedNameString;
            value yqn = yd.qualifiedNameString;
            return switch (xqn <=> yqn)
                case (smaller) -1
                case (larger) 1
                case (equal) 0;
        }
    }
    
    equals(Object that) => (super of Identifiable).equals(that);
    hash => (super of Identifiable).hash;
}