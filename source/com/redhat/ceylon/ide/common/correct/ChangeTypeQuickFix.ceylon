import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import com.redhat.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    TypeParameter,
    Declaration,
    Generic,
    IntersectionType,
    Type,
    TypedDeclaration,
    Function,
    ModelUtil,
    ClassOrInterface
}

shared object changeTypeQuickFix {
    
    shared void addChangeTypeArgProposals(QuickFixData data) {
        if (is Tree.SimpleType stn = data.node,
            is TypeParameter dec = stn.declarationModel) {
            
            class ArgumentListVisitor() extends Visitor() {
                shared variable Declaration? declaration = null;
                shared variable Tree.TypeArgumentList? typeArgs = null;
                
                shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                    super.visit(that);
                    value args = that.typeArguments;
                    if (is Tree.TypeArgumentList args) {
                        value tal = args;
                        if (tal.types.contains(stn)) {
                            declaration = that.declaration;
                            typeArgs = tal;
                        }
                    }
                }
                
                shared actual void visit(Tree.SimpleType that) {
                    super.visit(that);

                    if (is Tree.TypeArgumentList args = that.typeArgumentList) {
                        value tal = args;
                        if (tal.types.contains(stn)) {
                            declaration = that.declarationModel;
                            typeArgs = tal;
                        }
                    }
                }
            }
            
            value vis = ArgumentListVisitor();
            vis.visit(data.rootNode);
            value std = vis.declaration;
            
            if (is Generic g = std) {
                assert(exists tal = vis.typeArgs);
                value i = tal.types.indexOf(stn);
                if (exists tps = g.typeParameters,
                    tps.size() > i) {
                    
                    value stTypeParam = tps.get(i);
                    value sts = stTypeParam.satisfiedTypes;
                    
                    if (!sts.empty) {
                        value it = IntersectionType(data.rootNode.unit);
                        it.satisfiedTypes = sts;
                        
                        addChangeTypeProposalsInternal(data, data.node, 
                            it.canonicalize().type, dec, true);
                    }
                }
            }
        }
    }
    
    shared void addChangeTypeProposals(QuickFixData data) {
        variable Node node = data.node;
        
        if (is Tree.SpecifierExpression se = data.node) {
            if (exists e = se.expression) {
                node = e.term;
            }
        }
        
        if (is Tree.Expression e = node) {
            node = e.term;
        }
        
        if (is Tree.Term term = node) {
            Type? t = term.typeModel;
            if (!exists t) {
                return;
            }
            
            value type = node.unit.denotableType(t);
            value fav = FindInvocationVisitor(node);
            fav.visit(data.rootNode);
            value td = fav.parameter;
            if (exists td) {
                if (is Tree.InvocationExpression ie = node) {
                    node = ie.primary;
                }
                
                if (is Tree.BaseMemberExpression bme = node) {
                    addChangeTypeProposalsInternal(data, node, td.type, 
                        bme.declaration, true);
                }
                
                if (is Tree.QualifiedMemberExpression qme = node) {
                    addChangeTypeProposalsInternal(data, node, td.type, 
                        qme.declaration, true);
                }
                
                addChangeTypeProposalsInternal(data, node, type, td, false);
            }
        }
    }

    void addChangeTypeProposalsInternal(QuickFixData data, Node node, variable Type type,
        Declaration? dec, Boolean intersect) {
        
        if (exists dec, 
            is AnyModifiableSourceFile u = dec.unit, 
            exists phasedUnit = u.phasedUnit) {
            variable Type? t = null;
            variable Node? typeNode = null;
            if (is TypeParameter tp = dec) {
                t = tp.type;
                typeNode = node;
            }
            
            if (is TypedDeclaration dec) {
                value typedDec = dec;
                value fdv = FindDeclarationNodeVisitor(typedDec);
                phasedUnit.compilationUnit.visit(fdv);
                value dn = fdv.declarationNode;
                if (is Tree.TypedDeclaration decNode = dn) {
                    typeNode = decNode.type;
                    if (is Tree.Type tn = typeNode) {
                        t = tn.typeModel;
                    }
                }
            }
            
            //TODO: fix this condition to properly
            //      distinguish between a method
            //      reference and an invocation
            value nu = node.unit;
            if (dec is Function, nu.isCallableType(type)) {
                type = nu.getCallableReturnType(type);
            }
            
            if (exists tn = typeNode,
                !ModelUtil.isTypeUnknown(type)) {
                
                value rootNode = phasedUnit.compilationUnit;
                addChangeTypeProposal(tn, data, dec, type, rootNode);
                
                if (exists _t = t) {
                    value newType = if (intersect)
                                    then ModelUtil.intersectionType(t, type, u)
                                    else ModelUtil.unionType(t, type, u);
                    
                    if (!newType.isExactly(t),
                        !newType.isExactly(type)) {
                        addChangeTypeProposal(tn, data, dec, newType, rootNode);
                    }
                }
            }
        }
    }

    void addChangeTypeProposal(Node node, QuickFixData data, Declaration dec, Type newType,
        Tree.CompilationUnit cu) {
        
        if (!node.startIndex exists || !node.endIndex exists) {
            return;
        }
        
        if (newType.nothing) {
            return;
        }
        
        if (ModelUtil.isConstructor(dec)) {
            return;
        }
        
        value change = platformServices.document.createTextChange("Change Type", data.phasedUnit);
        change.initMultiEdit();
        value doc = change.document;
        value offset = node.startIndex.intValue();
        value length = node.distance.intValue();
        value importProposals = CommonImportProposals(doc, data.rootNode);
        importProposals.importType(newType);
        value il = importProposals.apply(change);
        value unit = cu.unit;
        value newTypeName = newType.asSourceCodeString(unit);
        change.addEdit(ReplaceEdit(offset, length, newTypeName));
        
        String name;
        if (dec.parameter,
            is Declaration container = dec.container) {
            name = "parameter '``dec.name``' of '`` container.name ``'";
        } else if (dec.classOrInterfaceMember) {
            assert (is ClassOrInterface container = dec.container);
            name = "member '``dec.name``' of '``container.name``'";
        } else {
            name = "'``dec.name``'";
        }

        data.addQuickFix {
            description = "Change type of ``name`` to '``newType.asString(unit)``'";
            change() => initializerQuickFix.apply(change, doc, unit);
            selection = DefaultRegion(offset + il, newTypeName.size);
            affectsOtherUnits = true;
        };
    }
}
