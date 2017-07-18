import ceylon.collection {
    HashSet
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Function,
    ClassOrInterface,
    Declaration,
    Type,
    Generic
}

import java.lang {
    overloaded
}
import java.util {
    List
}

shared object createTypeParameterQuickFix {

    shared void addCreateTypeParameterProposal(QuickFixData data, 
        Tree.BaseType type, String brokenName) {
        
        if (type.typeArgumentList exists) {
            return;
        }
        
        class FilterExtendsSatisfiesVisitor() extends Visitor() {
            shared variable Boolean filter = false;

            overloaded
            shared actual void visit(Tree.ExtendedType that) {
                super.visit(that);
                if (that.type == type) {
                    filter = true;
                }
            }

            overloaded
            shared actual void visit(Tree.SatisfiedTypes that) {
                super.visit(that);
                for (t in that.types) {
                    if (t == type) {
                        filter = true;
                    }
                }
            }

            overloaded
            shared actual void visit(Tree.CaseTypes that) {
                super.visit(that);
                for (t in that.types) {
                    if (t == type) {
                        filter = true;
                    }
                }
            }
        }
        
        value v = FilterExtendsSatisfiesVisitor();
        v.visit(data.rootNode);
        if (v.filter) {
            return;
        }
        
        
        [Tree.Declaration, Declaration]? findDeclaration() {
            variable value decl = nodes.findDeclarationWithBody(data.rootNode, type);
            if (!exists _ = decl) {
                decl = nodes.findDeclaration(data.rootNode, type);
                if (exists _decl = decl,
                    !(decl is Tree.AnyMethod|Tree.ClassOrInterface)) {
                    decl = nodes.getContainer(data.rootNode, _decl.declarationModel);
                }
            }
            
            value d = decl?.declarationModel;
            
            if (!exists d) {
                return null;
            }
            if (d.actual || !(d is Function|ClassOrInterface)) {
                return null;
            }
            
            assert(exists _decl = decl);
            
            return [_decl, d];
        }
        
        value tuple = findDeclaration();
        
        if (!exists tuple) {
            return;
        }
        value [decl, d] = tuple;
        
        value paramList = getTypeParameters(decl);
        variable String paramDef;
        variable Integer offset;
        if (exists paramList) {
            paramDef = ", " + brokenName;
            offset = paramList.endIndex.intValue() - 1;
        } else {
            paramDef = "<``brokenName``>";
            offset = nodes.getIdentifyingNode(decl)?.endIndex?.intValue() else 0;
        }
        
        class FindTypeParameterConstraintVisitor() extends Visitor() {
            shared variable List<Type>? result = null;

            overloaded
            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                if (exists dm = that.declarationModel) {
                    value tps = dm.typeParameters;
                    if (exists tal = that.typeArgumentList) {
                        value tas = tal.types;
                        variable value i = 0;
                        while (i < tas.size()) {
                            if (tas.get(i) == type) {
                                result = tps.get(i).satisfiedTypes;
                            }
                            
                            i++;
                        }
                    }
                }
            }

            overloaded
            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                super.visit(that);
                if (is Generic d = that.declaration) {
                    value tps = d.typeParameters;
                    value tas = that.typeArguments;
                    if (is Tree.TypeArgumentList tas) {
                        value ts = tas.types;
                        variable Integer i = 0;
                        while (i < ts.size()) {
                            if (ts.get(i) == type) {
                                result = tps.get(i).satisfiedTypes;
                            }
                            i++;
                        }
                    }
                }
            }
        }
        
        value ftpcv = FindTypeParameterConstraintVisitor();
        ftpcv.visit(data.rootNode);
        String? constraints;
        if (exists result = ftpcv.result) {
            value bounds = correctionUtil.asIntersectionTypeString { *result };
            if (bounds.empty) {
                constraints = null;
            } else {
                constraints = "given ``brokenName`` satisfies ``bounds`` ";
            }
        } else {
            constraints = null;
        }
        
        if (is AnyModifiableSourceFile msf = data.rootNode.unit) {
            addProposal {
                data = data;
                wasNotGeneric = !paramList exists;
                def = paramDef;
                name = brokenName;
                dec = d;
                phasedUnit = msf.phasedUnit;
                decNode = decl;
                offset = offset;
                constraints = constraints;
            };
        }
    }

    void addProposal(QuickFixData data, Boolean wasNotGeneric, String def,
        String name, Declaration dec, PhasedUnit? phasedUnit,
        Tree.Declaration decNode, Integer offset, String? constraints) {
        
        if (!exists phasedUnit) {
            return;
        }
        
        value change
                = platformServices.document
                    .createTextChange("Add Type Parameter", phasedUnit);
        change.initMultiEdit();
        value doc = change.document;

        value il = importProposals.applyImports {
            change = change;
            declarations = HashSet<Declaration>();
            rootNode = phasedUnit.compilationUnit;
            doc = doc;
        };
        
        change.addEdit(InsertEdit(offset, def));
        
        if (exists constraints) {
            value loc = getConstraintLoc(decNode);
            if (loc >= 0) {
                String text;
                try {
                    value start = doc.getLineStartOffset(loc);
                    value string = doc.getText(start, loc - start);

                    if (!string.trimmed.empty) {
                        value defaultIndent
                                = platformServices.document
                                    .defaultIndent;
                        text = doc.defaultLineDelimiter
                             + doc.getIndent(decNode)
                             + defaultIndent
                             + defaultIndent
                             + constraints;
                    }
                    else {
                        text = constraints;
                    }
                }
                catch (e) {
                    return;
                }
                
                change.addEdit(InsertEdit(loc, text));
            }
        }
        
        data.addQuickFix {
            description = "Add type parameter '``name``' to '``dec.name``'";
            change = change;
            selection = DefaultRegion {
                start = offset + il
                      + (wasNotGeneric then 1 else 2);
                length = name.size;
            };
        };
    }
    
    Integer getConstraintLoc(Tree.Declaration decNode) {
        switch (decNode)
        case (is Tree.ClassDefinition) {
            return decNode.classBody.startIndex.intValue();
        }
        case (is Tree.InterfaceDefinition) {
            return decNode.interfaceBody.startIndex.intValue();
        }
        case (is Tree.MethodDefinition) {
            return decNode.block.startIndex.intValue();
        }
        case (is Tree.ClassDeclaration) {
            return if (exists s = decNode.classSpecifier)
                   then s.startIndex.intValue()
                   else decNode.endIndex.intValue();
        }
        case (is Tree.InterfaceDeclaration) {
            return if (exists s = decNode.typeSpecifier)
                   then s.startIndex.intValue()
                   else decNode.endIndex.intValue();
        }
        case (is Tree.MethodDeclaration) {
            return if (exists s = decNode.specifierExpression)
                   then s.startIndex.intValue()
                   else decNode.endIndex.intValue();
        }
        else {
            return -1;
        }
    }
    
    Tree.TypeParameterList? getTypeParameters(Tree.Declaration decl) {
        switch (decl)
        case (is Tree.ClassOrInterface) {
            return decl.typeParameterList;
        }
        case (is Tree.AnyMethod) {
            return decl.typeParameterList;
        }
        else {
            return null;
        }
    }

}