/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree,
    TreeUtil {
        formatPath
    }
}
import org.eclipse.ceylon.model.typechecker.model {
    Scope,
    ModelUtil
}

shared class FindImportNodeVisitor(String packageName, Scope? scope)
        extends Visitor() {

    shared variable Tree.Import? result = null;

    shared actual void visit(Tree.Import that) {
        if (result exists) {
            return;
        }
        if (!scope exists || ModelUtil.contains(that.scope, scope)) {
            value path = formatPath(that.importPath.identifiers);
            if (path == packageName) {
                result = that;
            }
        }
    }

}
