import com.redhat.ceylon.common {
    Backends
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.imports {
    moduleImportUtil
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    TextChange,
    ReplaceEdit,
    TextEdit,
    CommonDocument
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    FindDeclarationNodeVisitor,
    types,
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Declaration,
    TypeDeclaration,
    Constructor,
    ModelUtil,
    Type,
    Class,
    ClassOrInterface,
    TypeAlias,
    TypedDeclaration,
    Package,
    Value,
    Module
}

import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}

shared object addAnnotationQuickFix {
    
    //    shared formal void newAddAnnotationQuickFix(Referenceable dec, String text, String desc, Integer offset,
    //        TextChange change, Region? selection, Data data);
    //
    //    shared formal void newCorrectionQuickFix(String desc, TextChange change, Region? selection,
    //        Data data);
    
    value annotationsOrder => ["doc", "throws", "see", "tagged", "shared", "abstract",
    "actual", "formal", "default", "variable"];
    
    value annotationsOnSeparateLine => ["doc", "throws", "see", "tagged"];
    
    shared void addMakeFormalDecProposal(Node node, QuickFixData data) {
        value dec = annotatedNode(node);
        value ann = if (dec.shared) then "formal" else "shared formal";
        value desc = if (dec.shared) then "Make Formal" else "Make Shared Formal";
        addAddAnnotationProposal(node, ann, desc, dec, data);
    }
    
    shared void addMakeAbstractDecProposal(Node node, QuickFixData data) {
        if (is Class dec = annotatedNode(node)) {
            addAddAnnotationProposal(node, "abstract", "Make Abstract", dec, data);
        }
    }
    
    shared void addMakeNativeProposal(Node node, QuickFixData data) {
        if (is Tree.ImportPath node) {
            object extends Visitor() {
                shared actual void visit(Tree.ModuleDescriptor that) {
                    assert(is Module m = node.model);
                    value backends = m.nativeBackends;
                    value change = platformServices.createTextChange("Declare Module Native", data.phasedUnit);
                    value annotation = StringBuilder();
                    moduleImportUtil.appendNative(annotation, backends);
                    change.addEdit(InsertEdit(that.startIndex.intValue(), annotation.string + " "));
                    data.addQuickFix("Declare module '" + annotation.string + "'", change);
                    
                    super.visit(that);
                }
                
                shared actual void visit(Tree.ImportModule that) {
                    if (that.importPath == node) {
                        assert (is Module m = that.importPath.model);
                        value backends = m.nativeBackends;
                        value change = platformServices.createTextChange("Declare Import Native", data.phasedUnit);
                        value annotation = StringBuilder();
                        moduleImportUtil.appendNative(annotation, backends);
                        change.addEdit(InsertEdit(that.startIndex.intValue(), annotation.string + " "));
                        data.addQuickFix("Declare import '" + annotation.string + "'", change);
                    }
                    
                    super.visit(that);
                }
            }.visit(data.rootNode);
        }
    }
    
    shared void addMakeContainerAbstractProposal(Node node, QuickFixData data) {
        Declaration dec;
        if (is Tree.Declaration node) {
            if (is Declaration container 
                = node.declarationModel.container) {
                dec = container;
            } else {
                return;
            }
        } else {
            assert (is Declaration scope = node.scope);
            dec = scope;
        }
        addAddAnnotationProposal(node, "abstract", "Make Abstract", dec, data);
    }
    
    shared void addMakeContainerNativeProposal(Node node, QuickFixData data) {
        if (is Declaration dec = node.scope) {
            Backends backends;
            if (is Tree.MemberOrTypeExpression node) {
                backends = node.declaration.nativeBackends;
            } 
            else if (is Tree.SimpleType node) {
                backends = node.declarationModel.nativeBackends;
            }
            else {
                return;
            }
            value annotation = StringBuilder();
            moduleImportUtil.appendNative(annotation, backends);
            addAddAnnotationProposal(node, annotation.string, "Make Native", dec, data);
        }
    }
    
    shared void addMakeVariableProposal(Node node, QuickFixData data) {
        Tree.Term term;
        switch (node)
        case (is Tree.AssignmentOp) {
            term = node.leftTerm;
        } case (is Tree.UnaryOperatorExpression) {
            term = node.term;
        } case (is Tree.MemberOrTypeExpression) {
            term = node;
        } case (is Tree.SpecifierStatement) {
            term = node.baseMemberExpression;
        } else {
            return;
        }
        
        if (is Tree.MemberOrTypeExpression term, 
            is Value dec = term.declaration, 
            !dec.originalDeclaration exists && !dec.transient) {
            addAddAnnotationProposal(node, "variable", "Make Variable", dec, data);
            if (dec.classMember) {
                addAddAnnotationProposal(node, "late", "Make Late", dec, data);
            }
        }
    }
    
    shared void addMakeVariableDeclarationProposal(QuickFixData data,
        Tree.Declaration node) {
        
        if (is Value dec = node.declarationModel,
            is Tree.AttributeDeclaration node,
            !dec.variable,
            !dec.transient) {
            
            addAddAnnotationProposal(node, "variable", "Make Variable",
                dec, data);
        }
    }
    
    shared void addMakeVariableDecProposal(QuickFixData data) {
        assert (is Tree.SpecifierOrInitializerExpression sie = data.node);
        variable Value? dec = null;
        object extends Visitor() {
            shared actual void visit(Tree.AttributeDeclaration that) {
                super.visit(that);
                if (that.specifierOrInitializerExpression == sie) {
                    dec = that.declarationModel;
                }
            }
        }.visit(data.rootNode);
        addAddAnnotationProposal(data.node, "variable", "Make Variable", dec, data);
    }
    
    Declaration annotatedNode(Node node) {
        if (is Tree.Declaration node) {
            return node.declarationModel;
        } else {
            assert (is Declaration scope = node.scope);
            return scope;
        }
    }
    
    shared void addMakeDefaultProposal(Node node, QuickFixData data) {
        variable Declaration? d;
        switch (node)
        case (is Tree.Declaration) {
            //get the supertype declaration we're refining
            d = types.getRefinedDeclaration(node.declarationModel);
        }
        case (is Tree.SpecifierStatement) {
            //get the supertype declaration we're referencing
            d = node.refined;
            /*} else if (is Tree.BaseMemberExpression node) {
                value bme = node;
                d = bme.declaration;
             */
        } else {
            return;
        }
        if (exists _d = d, _d.classOrInterfaceMember) {
            addAddAnnotationProposal(node, "default",
                "Make default", d, data);
            
            //assert (is ClassOrInterface container = d.container);
            //value rds = container.getInheritedMembers(d.name);
            //variable Declaration? rd = null;
            //if (rds.empty) {
            //    rd = d;
            //} else {
            //    for (r in rds) {
            //        if (!r.default) {
            //            rd = r;
            //            break;
            //        }
            //    }
            //}
            //if (exists _rd = rd) {
            //    addAddAnnotationProposal(node, "default", "Make Default", _rd, project, data);
            //}
        }
    }
    
    shared void addMakeDefaultDecProposal(Node node, QuickFixData data) {
        value dec = annotatedNode(node);
        addAddAnnotationProposal(node,
            dec.shared then "default" else "shared default",
            dec.shared then "Make Default" else "Make Shared Default",
            dec, data);
    }
    
    
    void addAddAnnotationProposal(Node? node, String annotation, String desc,
        Referenceable? dec, QuickFixData data) {
        
        if (exists dec, !(node is Tree.MissingDeclaration)) {
            
            value fdv = FindDeclarationNodeVisitor(dec);
            data.phasedUnit.compilationUnit.visit(fdv);
            value decNode = fdv.declarationNode;
            if (exists decNode) {
                addAddAnnotationProposal2(annotation, desc, dec, data.phasedUnit,
                    node, decNode, data);
            }
        }
    }
    
    void addAddAnnotationProposal2(String annotation, String desc, Referenceable dec,
        PhasedUnit unit, Node? node, Tree.StatementOrArgument decNode, QuickFixData data) {
        value change = platformServices.createTextChange(desc, unit);
        change.initMultiEdit();
        
        value edit = createReplaceAnnotationEdit(annotation, node, change)
        else createInsertAnnotationEdit(annotation, decNode,
            change.document);
        
        change.addEdit(edit);
        
        createExplicitTypeEdit(decNode, change);
        
        value startOffset = edit.start;
        value selection = 
                if (exists node, node.unit==decNode.unit) 
        then DefaultRegion(startOffset, annotation.size) 
        else null;
        
        data.addAnnotationProposal {
            declaration = dec;
            text = annotation;
            description = description(annotation, dec);
            change = change;
            selection = selection;
        };
    }
    
    void createExplicitTypeEdit(Tree.StatementOrArgument decNode, TextChange change) {
        if (is Tree.TypedDeclaration decNode, !(decNode is Tree.ObjectDefinition)) {
            value type = decNode.type;
            if (type.token exists, 
                type is Tree.FunctionModifier|Tree.ValueModifier, 
                exists it = type.typeModel, !it.unknown) {
                value explicitType = it.asString();
                change.addEdit(ReplaceEdit(type.startIndex.intValue(),
                    type.text.size, explicitType));
            }
        }
    }
    
    String description(String annotation, Referenceable dec) {
        String description;
        if (is Declaration dec) {
            value d = dec;
            value container = d.container;
            variable value containerDesc = "";
            if (is TypeDeclaration container) {
                variable String? name = container.name;
                if (!exists n = name, is Constructor container) {
                    value cont = container.container;
                    if (is Declaration cont) {
                        value cd = cont;
                        name = cd.name;
                    }
                }
                containerDesc = " in '" + (name else "") + "'";
            }
            String? name = d.name;
            if (!exists n = name, ModelUtil.isConstructor(d)) {
                description = "Make default constructor " + annotation + containerDesc;
            } else {
                description = "Make '" + (name else "") + "' " + annotation + containerDesc;
            }
        } else {
            description = "Make package '" + dec.nameAsString + "' " + annotation;
        }
        return description;
    }
    
    TextEdit? createReplaceAnnotationEdit(String annotation, Node? node, TextChange change) {
        String toRemove;
        if ("formal".equals(annotation)) {
            toRemove = "default";
        } else if ("abstract".equals(annotation)) {
            toRemove = "final";
        } else {
            return null;
        }
        if (exists annotationList = getAnnotationList(node)) {
            for (ann in annotationList.annotations) {
                if (exists id = getAnnotationIdentifier(ann), id == toRemove) {
                    value start = ann.startIndex.intValue();
                    value length = ann.endIndex.intValue() - start;
                    return ReplaceEdit(start, length, annotation);
                }
            }
        }
        return null;
    }
    
    shared InsertEdit createInsertAnnotationEdit(String newAnnotation, Node node, CommonDocument doc) {
        value newAnnotationName = getAnnotationWithoutParam(newAnnotation);
        variable Tree.Annotation? prevAnnotation = null;
        variable Tree.Annotation? nextAnnotation = null;
        if (exists annotationList = getAnnotationList(node)) {
            for (annotation in annotationList.annotations) {
                if (exists id = getAnnotationIdentifier(annotation),
                    isAnnotationAfter(newAnnotationName, id)) {
                    prevAnnotation = annotation;
                } else if (!nextAnnotation exists) {
                    nextAnnotation = annotation;
                    break;
                }
            }
        }
        Integer nextNodeStartIndex;
        if (exists ann = nextAnnotation) {
            nextNodeStartIndex = ann.startIndex.intValue();
        } else {
            if (is Tree.AnyAttribute|Tree.AnyMethod node) {
                nextNodeStartIndex = node.type.startIndex.intValue();
            } else if (is Tree.ObjectDefinition node) {
                assert (is CommonToken token = node.mainToken);
                nextNodeStartIndex = token.startIndex;
            } else if (is Tree.ClassOrInterface node) {
                assert (is CommonToken token = node.mainToken);
                nextNodeStartIndex = token.startIndex;
            } else {
                nextNodeStartIndex = node.startIndex.intValue();
            }
        }
        Integer newAnnotationOffset;
        value newAnnotationText = StringBuilder();
        if (isAnnotationOnSeparateLine(newAnnotationName), !(node is Tree.Parameter)) {
            if (exists ann = prevAnnotation, exists id = getAnnotationIdentifier(ann),
                isAnnotationOnSeparateLine(id)) {
                
                newAnnotationOffset = ann.endIndex.intValue();
                newAnnotationText.append(doc.defaultLineDelimiter);
                newAnnotationText.append(doc.getIndent(node));
                newAnnotationText.append(newAnnotation);
            } else {
                newAnnotationOffset = nextNodeStartIndex;
                newAnnotationText.append(newAnnotation);
                newAnnotationText.append(doc.defaultLineDelimiter);
                newAnnotationText.append(doc.getIndent(node));
            }
        } else {
            newAnnotationOffset = nextNodeStartIndex;
            newAnnotationText.append(newAnnotation);
            newAnnotationText.append(" ");
        }
        return InsertEdit(newAnnotationOffset, newAnnotationText.string);
    }
    
    shared Tree.AnnotationList? getAnnotationList(Node? node) {
        if (is Tree.Declaration node) {
            return node.annotationList;
        } else if (is Tree.ModuleDescriptor node) {
            return node.annotationList;
        } else if (is Tree.PackageDescriptor node) {
            return node.annotationList;
        } else if (is Tree.Assertion node) {
            return node.annotationList;
        } else {
            return null;
        }
    }
    
    shared String? getAnnotationIdentifier(Tree.Annotation? annotation) {
        return if (exists annotation,
            is Tree.BaseMemberExpression primary = annotation.primary)
        then primary.identifier.text
        else null;
    }
    
    String getAnnotationWithoutParam(String annotation) {
        if (exists index = annotation.firstOccurrence('(')) {
            return annotation.spanTo(index - 1).trimmed;
        }
        
        if (exists index = annotation.firstOccurrence('"')) {
            return annotation.spanTo(index - 1).trimmed;
        }
        
        if (exists index = annotation.firstOccurrence(' ')) {
            return annotation.spanTo(index - 1).trimmed;
        }
        return annotation.trimmed;
    }
    
    Boolean isAnnotationAfter(String annotation1, String annotation2) {
        value index1 = annotationsOrder.firstIndexWhere(annotation1.equals) else 0;
        value index2 = annotationsOrder.firstIndexWhere(annotation1.equals) else 0;
        return index1 >= index2;
    }
    
    Boolean isAnnotationOnSeparateLine(String annotation) 
            => annotation in annotationsOnSeparateLine;
    
    shared void addMakeActualDecProposal(Node node, QuickFixData data) {
        value dec = annotatedNode(node);
        value shared = dec.shared;
        addAddAnnotationProposal(node, if (shared) then "actual" else "shared actual",
            if (shared) then "Make Actual" else "Make Shared Actual", dec, data);
    }
    
    shared void addMakeSharedProposalForSupertypes(Node node, QuickFixData data) {
        if (is Tree.ClassOrInterface node) {
            value ci = node.declarationModel;
            if (exists extendedType = ci.extendedType) {
                addMakeSharedProposal2(extendedType.declaration, data);
                for (typeArgument in extendedType.typeArgumentList) {
                    addMakeSharedProposal2(typeArgument.declaration, data);
                }
            }
            if (exists satisfiedTypes = ci.satisfiedTypes) {
                for (satisfiedType in satisfiedTypes) {
                    addMakeSharedProposal2(satisfiedType.declaration, data);
                    for (typeArgument in satisfiedType.typeArgumentList) {
                        addMakeSharedProposal2(typeArgument.declaration, data);
                    }
                }
            }
        }
    }
    
    shared void addMakeRefinedSharedProposal(Node node, QuickFixData data) {
        if (is Tree.Declaration node) {
            value refined = node.declarationModel.refinedDeclaration;
            if (refined.default || refined.formal) {
                addMakeSharedProposal2(refined, data);
            } else {
                addAddAnnotationProposal(node, "shared default", "Make Shared Default", refined, data);
            }
        }
    }
    
    shared void addMakeSharedProposal(Node node, QuickFixData data) {
        variable Referenceable? dec = null;
        variable JList<Type>? typeArgumentList = null;
        switch (node)
        case (is Tree.StaticMemberOrTypeExpression) {
            dec = node.declaration;
        } case (is Tree.SimpleType) {
            dec = node.declarationModel;
        } case (is Tree.OptionalType) {
            if (is Tree.SimpleType st = node.definiteType) {
                dec = st.declarationModel;
            }
        } case (is Tree.IterableType) {
            if (is Tree.SimpleType st = node.elementType) {
                dec = st.declarationModel;
            }
        } case (is Tree.SequenceType) {
            if (is Tree.SimpleType st = node.elementType) {
                dec = st.declarationModel;
            }
        } case (is Tree.ImportMemberOrType) {
            dec = node.declarationModel;
        } case (is Tree.ImportPath) {
            dec = node.model;
        } case (is Tree.TypedDeclaration) {
            if (exists td = node.declarationModel) {
                value pt = td.type;
                dec = pt.declaration;
                typeArgumentList = pt.typeArgumentList;
            }
        } case (is Tree.Parameter) {
            if (exists param = node.parameterModel, exists p = param.type) {
                value pt = param.type;
                dec = pt.declaration;
                typeArgumentList = pt.typeArgumentList;
            }
        }
        else {}
        addMakeSharedProposal2(dec, data);
        if (exists tal = typeArgumentList) {
            for (typeArgument in tal) {
                addMakeSharedProposal2(typeArgument.declaration, data);
            }
        }
    }
    
    void addMakeSharedProposal2(Referenceable? ref, QuickFixData data) {
        if (exists ref) {
            if (is TypedDeclaration|ClassOrInterface|TypeAlias ref) {
                if (!ref.shared) {
                    addAddAnnotationProposal(null, "shared", "Make Shared", ref, data);
                }
            } else if (is Package ref) {
                if (!ref.shared) {
                    addAddAnnotationProposal(null, "shared", "Make Shared", ref, data);
                }
            }
        }
    }
    
    shared void addMakeSharedDecProposal(Node node, QuickFixData data) {
        if (is Tree.Declaration node) {
            addAddAnnotationProposal(node, "shared", "Make Shared", node.declarationModel, data);
        }
    }
    
    shared void addContextualAnnotationProposals(QuickFixData data, Tree.Declaration? decNode, 
        Integer offset) {
        
        value doc = data.document;
        
        if (exists decNode) {
            value idNode = nodes.getIdentifyingNode(decNode);
            if (!exists idNode) {
                return;
            }
            if (doc.getLineOfOffset(idNode.startIndex.intValue())
                != doc.getLineOfOffset(offset)) {
                
                return;
            }
            
            if (exists d = decNode.declarationModel) {
                if (is Tree.AttributeDeclaration decNode) {
                    addMakeVariableDeclarationProposal(data, decNode);
                }
                
                if ((d.classOrInterfaceMember || d.toplevel), !d.shared) {
                    addMakeSharedDecProposal(decNode, data);
                }
                
                if (d.classOrInterfaceMember, !d.default, !d.formal) {
                    switch (decNode)
                    case (is Tree.AnyClass) {
                        addMakeDefaultDecProposal(decNode, data);
                    } case (is Tree.AnyAttribute) {
                        addMakeDefaultDecProposal(decNode, data);
                    } case (is Tree.AnyMethod) {
                        addMakeDefaultDecProposal(decNode, data);
                    } else {}
                    
                    switch (decNode)
                    case (is Tree.ClassDefinition) {
                        addMakeFormalDecProposal(decNode, data);
                    } case (is Tree.AttributeDeclaration) {
                        if (!decNode.specifierOrInitializerExpression exists) {
                            addMakeFormalDecProposal(decNode, data);
                        }
                    } case (is Tree.MethodDeclaration) {
                        value md = decNode;
                        if (!md.specifierExpression exists) {
                            addMakeFormalDecProposal(decNode, data);
                        }
                    } else {}
                }
            }
        }
    }
}
