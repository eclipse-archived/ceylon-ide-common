import ceylon.collection {
    HashSet
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit,
    CommonDocument
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    ModelUtil {
        isTypeUnknown
    },
    Declaration
}

shared object specifyTypeQuickFix {
    
    shared DefaultRegion? specifyType(Tree.CompilationUnit rootNode,
            CommonDocument document, Tree.Type typeNode,
            Boolean inEditor, Type type) {
        
        value offset = typeNode.startIndex.intValue();
        value length = typeNode.distance.intValue();
        value unit = rootNode.unit;
        value infType = unit.denotableType(type);
        
        if (!inEditor) {
            if (is Tree.LocalModifier typeNode) {
                value change 
                        = platformServices.document.createTextChange {
                    name = "Specify Type";
                    input = document;
                };
                change.initMultiEdit();
                value decs = HashSet<Declaration>();
                importProposals.importType {
                    declarations = decs;
                    type = infType;
                    rootNode = rootNode;
                    scope = typeNode.scope;
                };
                value il = importProposals.applyImports {
                    change = change;
                    declarations = decs;
                    rootNode = rootNode;
                    doc = document;
                };
                value typeName 
                        = infType.asSourceCodeString(unit);
                change.addEdit(ReplaceEdit {
                        start = offset;
                        length = length;
                        text = typeName;
                    });
                
                change.apply();
                
                return DefaultRegion {
                    start = offset + il;
                    length = typeName.size;
                };
            }
        } else {
            value proposals = typeCompletion.getTypeProposals {
                rootNode = rootNode;
                offset = offset;
                length = length;
                infType = infType;
                kind = null;
            };
            value lm = platformServices.createLinkedMode(document);
            lm.addEditableRegion {
                start = offset;
                length = length;
                exitSeqNumber = 0;
                proposals = proposals;
            };
            lm.install(this, -1, -1);
        }
        
        return null;
    }
    
    shared void addSpecifyTypeProposal(Node node, QuickFixData data) 
            => createProposals(node, data);

    shared void createProposal(Tree.Type type, QuickFixData data) 
            => newProposal {
                desc = "Declare explicit type";
                type = type;
                infType = type.typeModel;
                data = data;
            };

    void createProposals(Node node, QuickFixData data) {
        Tree.Type type;
        switch (node)
        case (is Tree.Type) {
            type = node;
        }
        case (is Tree.SpecifierExpression) {
            if (is Tree.TypedDeclaration td = 
                nodes.findDeclaration(data.rootNode, node)) {
                type = td.type;
            }
            else {
                return;
            }
        }
        else {
            return;
        }
        value result = inferType(data.rootNode, type);
        value declaredType = type.typeModel;
        
        value it = result.inferredType;
        value gt = result.generalizedType;
        if (!isTypeUnknown(declaredType)) {
            if (type is Tree.VoidModifier) {
                if (exists it, !isTypeUnknown(it)) {
                    newProposal("Declare return type", type, it, data);
                }
            }
            else {
                if (exists gt, !isTypeUnknown(gt), 
                    isTypeUnknown(it) || !gt.isSubtypeOf(it),
                    !gt.isSubtypeOf(declaredType)) {
                    newProposal("Widen type to", type, gt, data);
                }
                
                if (exists it, !isTypeUnknown(it)) {
                    if (!it.isSubtypeOf(declaredType)) {
                        newProposal("Change type to", type, it, data);
                    } else if (!declaredType.isSubtypeOf(it)) {
                        newProposal("Narrow type to", type, it, data);
                    }
                }
                
                if (type is Tree.LocalModifier) {
                    newProposal("Declare explicit type", type, declaredType, data);
                }
            }
            
        } else {
            if (exists it, !isTypeUnknown(it)) {
                newProposal("Declare type", type, it, data);
            }
            
            if (exists gt, !isTypeUnknown(gt), 
                isTypeUnknown(it) || !gt.isSubtypeOf(it)) {
                newProposal("Declare type", type, gt, data);                    
            }
        }
    }

    InferredType inferType(Tree.CompilationUnit cu, Tree.Type type) {
        value itv = object extends InferTypeVisitor(type.unit) {
            shared actual void visit(Tree.TypedDeclaration that) {
                if (exists t = that.type, t == type) {
                    declaration = that.declarationModel;
                    // union(that.getType().getTypeModel());
                }
                super.visit(that);
            }
        };
        itv.visit(cu);
        return itv.result;
    }

    shared void addTypingProposals(QuickFixData data, Tree.Declaration? decNode) {
        if (is Tree.TypedDeclaration decNode, 
            !(decNode is Tree.ObjectDefinition|Tree.Variable)) {
            Tree.Type? type = decNode.type;
            if (is Tree.LocalModifier|Tree.StaticType type) {
                addSpecifyTypeProposal(type, data);
            }
        } else if (is Tree.LocalModifier|Tree.StaticType node = data.node) {
            addSpecifyTypeProposal(node, data);
        }
    }
    
    void newProposal(String desc, Tree.Type type, Type infType, QuickFixData data) {
        
        data.addQuickFix {
            description = "``desc`` '``infType.asString(data.rootNode.unit)``'";
            image = Icons.reveal;
            void change() {
                 specifyType {
                     rootNode = data.rootNode;
                     document = data.document;
                     typeNode = type;
                     inEditor = true;
                     type = infType;
                 };
            }
        };
    }
}
