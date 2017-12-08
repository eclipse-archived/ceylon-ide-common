/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.analyzer {
    UsageWarning,
    Warning
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    VisitorAdaptor
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit,
    InsertEdit
}
import org.eclipse.ceylon.model.typechecker.model {
    TypeDeclaration
}
import org.eclipse.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import org.antlr.runtime {
    CommonToken
}

"Quick fixes for [[Warning.syntaxDeprecation]]."
object syntaxDeprecationQuickFix {

    shared void addProposal(QuickFixData data, UsageWarning warning ) {
        if (warning.warningName == Warning.syntaxDeprecation.name()) {
            addQualifyStaticMemberWithTypeProposal(data);
            replaceValueDestructuring(data);
        }
    }

    "Replaces `value` destructuring with `let` destructuring.
     
         value [a, b, c] = [1, 2, 3];
     
     becomes
     
         let ([a, b, c] = [1, 2, 3]);
     "
    void replaceValueDestructuring(QuickFixData data) {
        if (is Tree.LetStatement statement = data.node,
            is CommonToken token = statement.token,
            token.type == CeylonLexer.valueModifier) {

            value change = platformServices.document.createTextChange {
                name = "Replace Value with Let";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            change.addEdit(ReplaceEdit {
                start = token.startIndex;
                length = token.stopIndex - token.startIndex + 2;
                text = "let (";
            });
            change.addEdit(InsertEdit {
                start = statement.endIndex.intValue() - 1;
                text = ")";
            });
            data.addQuickFix {
                description = "Replace 'value' destructuring with 'let'";
                change = change;
            };
        }
    }

    "Qualifies a reference to a static member by type.

         myInt.parse(\"1\");

     becomes

         Integer.parse(\"1\");
     "
    shared void addQualifyStaticMemberWithTypeProposal(QuickFixData data) {
        if (is Tree.Primary node = data.node) {
            object vis extends VisitorAdaptor() {
                shared variable Tree.QualifiedMemberOrTypeExpression? result = null;

                shared actual void visitQualifiedMemberOrTypeExpression(Tree.QualifiedMemberOrTypeExpression that) {
                    if (that.primary == node) {
                        result = that;
                    }
                    super.visitQualifiedMemberOrTypeExpression(that);
                }
            }
            vis.visitCompilationUnit(data.rootNode);

            if (exists result = vis.result,
                result.declaration.static,
                !result.staticMethodReference,
                is TypeDeclaration type = result.declaration.container) {

                value typeName = type.getName(data.rootNode.unit);
                value change = platformServices.document.createTextChange {
                    name = "Qualify Static Member with Type";
                    input = data.phasedUnit;
                };
                change.addEdit(ReplaceEdit {
                    start = data.node.startIndex.intValue();
                    length = data.node.distance.intValue();
                    text = typeName;
                });
                data.addQuickFix {
                    description = "Qualify '``result.identifier.text``' with '``typeName``'";
                    change = change;
                };
            }
        }
    }
}
