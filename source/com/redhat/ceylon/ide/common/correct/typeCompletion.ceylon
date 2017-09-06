import ceylon.collection {
    HashSet
}
import ceylon.interop.java {
    CeylonList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    AbstractCompletionProposal,
    ProposalsHolder
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    CommonDocument,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil,
    Type,
    Declaration
}

import java.lang {
    Character
}

shared object typeCompletion {
    
    shared ProposalsHolder getTypeProposals(Tree.CompilationUnit rootNode, Integer offset,
        Integer length, Type infType, String? kind) {
        
        value td = infType.declaration;
        value supertypes
                = if (ModelUtil.isTypeUnknown(infType)
                        || infType.typeConstructor)
                then [] else CeylonList(td.supertypeDeclarations);
        variable value size = supertypes.size;
        
        if (exists kind) {
            size++;
        }
        if (infType.typeConstructor
            || infType.typeParameter
            || infType.union
            || infType.intersection) {
            size++;
        }

        value proposals = platformServices.completion.createProposalsHolder();
        
        if (exists kind) {
            platformServices.completion.newTypeProposal {
                proposals = proposals;
                rootNode = rootNode;
                offset = offset;
                type = null;
                text = kind;
                desc = kind;
            };
        }
        value unit = rootNode.unit;
        if (infType.typeConstructor
            || infType.typeParameter
            || infType.union
            || infType.intersection) {
            
            platformServices.completion.newTypeProposal {
                proposals = proposals;
                rootNode = rootNode;
                offset = offset;
                type = infType;
                text = infType.asSourceCodeString(unit);
                desc = infType.asString(unit);
            };
        }
        
        value sortedSupertypes
                = supertypes.sort((x, y) {
                    if (x.inherits(y)) {
                        return smaller;
                    }
                    if (y.inherits(x)) {
                        return larger;
                    }
                    return x.name <=> y.name;
                });
        
        for (supertype in sortedSupertypes) {
            value type = infType.getSupertype(supertype);
            platformServices.completion.newTypeProposal {
                proposals = proposals;
                rootNode = rootNode;
                offset = offset;
                type = type;
                text = type.asSourceCodeString(unit);
                desc = type.asString(unit);
            };
        }
        
        return proposals;
    }
}

shared abstract class TypeProposal
        (Integer offset, Type? type, String text, String desc, Tree.CompilationUnit rootNode)
        extends AbstractCompletionProposal(offset, "", desc, text) {
    
    shared DefaultRegion applyChange(CommonDocument document) {
        value change = platformServices.document.createTextChange("Specify Type", document);
        change.initMultiEdit();
        value decs = HashSet<Declaration>();
        if (exists type) {
            importProposals.importType(decs, type, rootNode);
        }
        
        value il = importProposals.applyImports {
            change = change;
            declarations = decs;
            rootNode = rootNode;
            scope = rootNode.scope; //TODO: this is wrong!
            doc = document;
        };
        change.addEdit(ReplaceEdit {
            start = offset;
            length = getCurrentLength(document);
            text = text;
        });

        return DefaultRegion(offset+il, text.size);
    }
    
    Integer getCurrentLength(CommonDocument document) {
        variable value length = 0;
        variable value i = offset;
        while (i < document.size) {
            if (Character.isWhitespace(document.getChar(i))) {
                break;
            }
            length++;
            i++;
        }
        return length;
    }


}