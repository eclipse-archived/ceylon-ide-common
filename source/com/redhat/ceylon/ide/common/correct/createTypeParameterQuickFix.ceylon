import ceylon.interop.java {
    CeylonIterable
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

import java.util {
    List,
    HashSet
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}

shared object createTypeParameterQuickFix {

    shared void addCreateTypeParameterProposal(QuickFixData data, 
        Tree.BaseType type, String brokenName) {
        
        if (type.typeArgumentList exists) {
            return;
        }
        
        class FilterExtendsSatisfiesVisitor() extends Visitor() {
            shared variable Boolean filter = false;
            shared actual void visit(Tree.ExtendedType that) {
                super.visit(that);
                if (that.type == type) {
                    filter = true;
                }
            }
            
            shared actual void visit(Tree.SatisfiedTypes that) {
                super.visit(that);
                for (t in that.types) {
                    if (t == type) {
                        filter = true;
                    }
                }
            }
            
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
            if (d.actual || !(d is Function || d is ClassOrInterface)) {
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
            paramDef = "<" + brokenName + ">";
            offset = nodes.getIdentifyingNode(decl)?.endIndex?.intValue() else 0;
        }
        
        class FindTypeParameterConstraintVisitor() extends Visitor() {
            shared variable List<Type>? result = null;
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
            
            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                super.visit(that);
                value d = that.declaration;
                if (is Generic d) {
                    value g = d;
                    value tps = g.typeParameters;
                    value tas = that.typeArguments;
                    if (is Tree.TypeArgumentList tas) {
                        value tal = tas;
                        value ts = tal.types;
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
            value bounds = correctionUtil.asIntersectionTypeString(CeylonIterable(result));
            if (bounds.empty) {
                constraints = null;
            } else {
                constraints = "given " + brokenName + " satisfies " + bounds + " ";
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
        
        value change = platformServices.createTextChange("Add Type Parameter", phasedUnit);
        change.initMultiEdit();
        
        value doc = change.document;
        value decs = HashSet<Declaration>();
        value cu = phasedUnit.compilationUnit;
        value il = importProposals.applyImports(change, decs, cu, change.document);
        
        change.addEdit(InsertEdit(offset, def));
        
        if (exists constraints) {
            value loc = getConstraintLoc(decNode);
            if (loc >= 0) {
                value start = doc.getLineStartOffset(loc);
                value string = doc.getText(start, loc - start);

                String text;
                if (!string.trimmed.empty) {
                    text = doc.defaultLineDelimiter
                            + doc.getIndent(decNode)
                            + platformServices.defaultIndent
                            + platformServices.defaultIndent
                            + constraints;
                } else {
                    text = constraints;
                }
                
                change.addEdit(InsertEdit(loc, text));
            }
        }
        
        value desc = "Add type parameter '" + name + "'" + " to '" + dec.name + "'";
        value off = if (wasNotGeneric) then 1 else 2;
        
        data.addQuickFix(desc, change, DefaultRegion(offset + il + off, name.size));
    }
    
    Integer getConstraintLoc(Tree.Declaration decNode) {
        if (is Tree.ClassDefinition decNode) {
            return decNode.classBody.startIndex.intValue();
        } else if (is Tree.InterfaceDefinition decNode) {
            return decNode.interfaceBody.startIndex.intValue();
        } else if (is Tree.MethodDefinition decNode) {
            return decNode.block.startIndex.intValue();
        } else if (is Tree.ClassDeclaration decNode) {
            return if (exists s = decNode.classSpecifier)
                   then s.startIndex.intValue()
                   else decNode.endIndex.intValue();
        } else if (is Tree.InterfaceDeclaration decNode) {
            return if (exists s = decNode.typeSpecifier)
                   then s.startIndex.intValue()
                   else decNode.endIndex.intValue();
        } else if (is Tree.MethodDeclaration decNode) {
            return if (exists s = decNode.specifierExpression)
                   then s.startIndex.intValue()
                   else decNode.endIndex.intValue();
        } else {
            return -1;
        }
    }
    
    Tree.TypeParameterList? getTypeParameters(Tree.Declaration decl) {
        if (is Tree.ClassOrInterface decl) {
            value ci = decl;
            return ci.typeParameterList;
        } else if (is Tree.AnyMethod decl) {
            value am = decl;
            return am.typeParameterList;
        }
        
        return null;
    }

}