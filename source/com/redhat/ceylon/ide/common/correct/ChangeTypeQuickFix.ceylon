import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import com.redhat.ceylon.model.typechecker.model {
    TypeParameter,
    Declaration,
    Generic,
    IntersectionType,
    Unit,
    Type,
    TypedDeclaration,
    Function,
    ModelUtil,
    ClassOrInterface
}
import com.redhat.ceylon.ide.common.model {
    ModifiableSourceFile
}
import com.redhat.ceylon.ide.common.util {
    FindDeclarationNodeVisitor
}
import java.util {
    HashSet
}
shared interface ChangeTypeQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, TextChange change,
        Integer offset, Integer length, Unit unit);
    
    shared void addChangeTypeArgProposals(Data data, IFile file) {
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
                            it.canonicalize().type, dec, true, file);
                    }
                }
            }
        }
    }
    
    shared void addChangeTypeProposals(Data data, IFile file) {
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
                    value d = bme.declaration;
                    addChangeTypeProposalsInternal(data, node, td.type, d, true, file);
                }
                
                if (is Tree.QualifiedMemberExpression qme = node) {
                    value d = qme.declaration;
                    addChangeTypeProposalsInternal(data, node, td.type, d, true, file);
                }
                
                addChangeTypeProposalsInternal(data, node, type, td, false, file);
            }
        }
    }

    void addChangeTypeProposalsInternal(Data data, Node node, variable Type type,
        Declaration? dec, Boolean intersect, IFile file) {
        
        if (exists dec) {
            value u = dec.unit;
            if (is ModifiableSourceFile<out Anything,out Anything,out Anything,out Anything> u) {
                value msf = u;
                assert(exists phasedUnit = msf.phasedUnit);
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
                    addChangeTypeProposal(tn, data, dec, type, file, rootNode);
                    
                    if (exists _t = t) {
                        value newType = if (intersect)
                                        then ModelUtil.intersectionType(t, type, u)
                                        else ModelUtil.unionType(t, type, u);
                        
                        if (!newType.isExactly(t),
                            !newType.isExactly(type)) {
                            addChangeTypeProposal(tn, data, dec, newType, file, rootNode);
                        }
                    }
                }
            }
        }
    }

    void addChangeTypeProposal(Node node, Data data, Declaration dec, Type newType,
        IFile file, Tree.CompilationUnit cu) {
        
        if (!node.startIndex exists || !node.endIndex exists) {
            return;
        }
        
        if (newType.nothing) {
            return;
        }
        
        if (ModelUtil.isConstructor(dec)) {
            return;
        }
        
        value change = newTextChange("Change Type", file);
        initMultiEditChange(change);
        value doc = getDocumentForChange(change);
        value offset = node.startIndex.intValue();
        value length = node.distance.intValue();
        value decs = HashSet<Declaration>();
        importProposals.importType(decs, newType, cu);
        value il = importProposals.applyImports(change, decs, cu, doc);
        value unit = cu.unit;
        value newTypeName = newType.asSourceCodeString(unit);
        addEditToChange(change, newReplaceEdit(offset, length, newTypeName));
        
        String name;
        if (dec.parameter) {
            assert (is Declaration container = dec.container);
            name = "parameter '``dec.name``' of '``container.name``'";
        } else if (dec.classOrInterfaceMember) {
            assert (is ClassOrInterface container = dec.container);
            name = "member '``dec.name``' of '``container.name``'";
        } else {
            name = "'" + dec.name + "'";
        }
        
        value desc = "Change type of ``name`` to '``newType.asString(unit)``'";
        newProposal(data, desc, change, offset + il, newTypeName.size, unit);
    }
}
