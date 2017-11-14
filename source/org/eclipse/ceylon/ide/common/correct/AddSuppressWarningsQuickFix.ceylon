/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Node,
    Visitor
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import java.lang {
    overloaded
}

"Adds a [[suppressWarnings]] annotation to a declaration to
 remove warnings.
 
     value a = nothing;
 
 becomes
 
     suppressWarnings(\"expressionTypeNothing\")
     value a = nothing;
 "
shared object addSuppressWarningsQuickFix {

    shared void addProposal(QuickFixData data) {
        value target = findAnnotatable {
            rootNode = data.rootNode;
            node = data.node;
        };
        if (!exists target) {
            return;
        }
        
        value doc = data.document;
        value change = platformServices.document.createTextChange {
            name = "Suppress Warnings";
            input = data.phasedUnit;
        };
        value sb = StringBuilder();
        value ss = StringBuilder().append("Suppress warnings of type ");
        target.visit(CollectWarningsToSuppressVisitor(sb, ss));
        value ws =
                doc.defaultLineDelimiter +
                doc.getIndent(target);
        variable value text = "suppressWarnings(" + sb.string + ")";
        variable value start = target.startIndex.intValue();
        value al = annotationList(target);
        if (!exists al) {
            text += ws;
        }
        else {
            if (exists aa = al.anonymousAnnotation) {
                start = aa.endIndex.intValue();
                text = ws + text;
            }
            else {
                text += ws;
            }
        }
        
        change.addEdit(InsertEdit(start, text));
        data.addQuickFix {
            description = ss.string;
            change = change;
            selection = DefaultRegion(start+text.size, 0);
            image = Icons.suppressWarnings;
        };
    }
    
    Tree.StatementOrArgument? findAnnotatable(Tree.CompilationUnit rootNode, Node? node) {
        class FindAnnotatableVisitor() extends Visitor() {
            variable shared Tree.StatementOrArgument? result = null;
            variable Tree.StatementOrArgument? current = null;

            overloaded
            shared actual void visit(Tree.Declaration that) {
                if (that is Tree.Variable
                          | Tree.TypeConstraint
                          | Tree.TypeParameterDeclaration) {
                    super.visit(that);
                }
                else {
                    value last = current;
                    current = that;
                    super.visit(that);
                    current = last;
                }
            }

            overloaded
            shared actual void visit(Tree.ModuleDescriptor that) {
                value last = current;
                current = that;
                super.visit(that);
                current = last;
            }

            overloaded
            shared actual void visit(Tree.PackageDescriptor that) {
                value last = current;
                current = that;
                super.visit(that);
                current = last;
            }
            
            shared actual void visitAny(Node that) {
                if (exists node, that == node) {
                    result = current;
                }
                
                if (!exists r = result) {
                    super.visitAny(that);
                }
            }
        }
        
        value fav = FindAnnotatableVisitor();
        fav.visit(rootNode);
        value target = fav.result;
        return target;
    }

    Tree.AnnotationList? annotationList(Node node)
            => switch (node)
            case (is Tree.Declaration) node.annotationList
            case (is Tree.ModuleDescriptor) node.annotationList
            case (is Tree.PackageDescriptor) node.annotationList
            case (is Tree.ImportModule) node.annotationList
            else null;
    
    class CollectWarningsToSuppressVisitor(StringBuilder sb, StringBuilder ss) extends Visitor() {
        
        shared actual void visitAny(Node node) {
            for (m in node.errors) {
                if (is UsageWarning warning = m) {
                    value warningName = warning.warningName;
                    if (!sb.string.contains(warningName)) {
                        if (!sb.empty) {
                            sb.append(", ");
                            ss.append(", ");
                        }
                        
                        sb.append("\"")
                                .append(warningName)
                                .append("\"");
                        ss.append("'\"")
                                .append(warningName)
                                .append("\"'");
                    }
                }
            }
            
            super.visitAny(node);
        }
    }

}