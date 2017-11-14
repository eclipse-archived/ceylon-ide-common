/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import java.lang {
    StringBuilder
}

shared interface DocumentServices {

    shared formal TextChange createTextChange(String name, CommonDocument|PhasedUnit input);

    shared formal CompositeChange createCompositeChange(String name);

    shared formal Integer indentSpaces;

    shared formal Boolean indentWithSpaces;

    shared String defaultIndent {
        StringBuilder result = StringBuilder();
        initialIndent(result);
        return result.string;
    }

    shared void initialIndent(StringBuilder buf) {
        //guess an initial indent level
        if (indentWithSpaces) {
            value spaces = indentSpaces;
            for (i in 1..spaces) {
                buf.append(' ');
            }
        }
        else {
            buf.append('\t');
        }
    }
}