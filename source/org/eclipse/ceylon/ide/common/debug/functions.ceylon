/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Node,
    Visitor
}
import ceylon.collection {
    TreeMap
}
import java.util.regex {
    Pattern
}
import org.eclipse.ceylon.common {
    JVMModuleUtil
}
import java.lang {
    overloaded
}


shared <Integer->Node>? getFirstValidLocation(Tree.CompilationUnit rootNode,
    CommonDocument document, Integer requestedLine) {

    value nodes = TreeMap<Integer, Node>(uncurry(Integer.compare));
    
    object extends Visitor() {
        void check(Node node) {
            if (exists startIndex = node.startIndex?.intValue(),
                exists stopIndex = node.endIndex?.intValue()) {

                value adjustedStopIndex = stopIndex + 1;
                value nodeStartLine = document.getLineOfOffset(startIndex);

                if (nodeStartLine >= requestedLine) {
                    nodes[nodeStartLine] = node;
                } else {
                    value nodeEndLine = document.getLineOfOffset(adjustedStopIndex);
                    if (nodeEndLine >= requestedLine) {
                        nodes[requestedLine] = node;
                    }
                }
            }
        }

        overloaded
        shared actual void visit(Tree.Annotation that) {}

        overloaded
        shared actual void visit(Tree.ExecutableStatement that) {
            check(that);
            super.visit(that);
        }

        overloaded
        shared actual void visit(Tree.SpecifierOrInitializerExpression that) {
            check(that);
            super.visit(that);
        }

        overloaded
        shared actual void visit(Tree.Expression that) {
            check(that);
            super.visit(that);
        }
    }.visit(rootNode);
    
    return nodes.first;
}

"Matches local variable names like `i$20`."
shared Pattern localVariablePattern = Pattern.compile("([^$]+)\\$[0-9]+");

"Transforms a variable name from its bytecode form to its original Ceylon source form."
shared String fixVariableName(variable String name, Boolean isLocalVariable, Boolean isSynthetic) {
    if (isSynthetic, name.startsWith("val$")) {
        name = name.removeInitial("val$");
    }
    if (exists c = name.first,
        c == '$') {
        if (JVMModuleUtil.isJavaKeyword(name, 1, name.size)) {
            name = name.substring(1);
        }
    }

    if (isLocalVariable || isSynthetic,
        name.contains("$")) {

        if (name.endsWith("$param$")) {
            return name.substring(0, name.size - "$param$".size);
        }
        value matcher = localVariablePattern.matcher(name);
        if (matcher.matches()) {
            name = matcher.group(1);
        }
    }
    return name;
}
