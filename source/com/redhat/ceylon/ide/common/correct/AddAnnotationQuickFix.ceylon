import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.util {
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Declaration,
    TypeDeclaration,
    Constructor,
    ModelUtil,
    Type,
    UnknownType,
    Class,
    Unit,
    ClassOrInterface,
    TypeAlias,
    TypedDeclaration,
    Package,
    Value
}

import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}

shared interface AddAnnotationQuickFix<IDocument,InsertEdit,TextEdit,TextChange,Region,Project>
        satisfies AbstractAnnotationQuickFix<IDocument, TextEdit, TextChange, Region, Project>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit {
    
    shared formal void newAddAnnotationQuickFix(Referenceable dec, String text, String desc, Integer offset,
        TextChange change, Region? selection);

    value annotationsOrder => ["doc", "throws", "see", "tagged", "shared", "abstract",
        "actual", "formal", "default", "variable"];
    
    value annotationsOnSeparateLine => ["doc", "throws", "see", "tagged"];
    
    shared void addMakeFormalDecProposal(Project project, Node node) {
        value dec = annotatedNode(node);
        value ann = if (dec.shared) then "formal" else "shared formal";
        value desc = if (dec.shared) then "Make Formal" else "Make Shared Formal";
        addAddAnnotationProposal(node, ann, desc, dec, project);
    }

    shared void addMakeAbstractDecProposal(Node node, Project p) {
        value dec = annotatedNode(node);
        if (is Class dec) {
            addAddAnnotationProposal(node, "abstract", "Make Abstract", dec, p);
        }
    }
    
    shared void addMakeContainerAbstractProposal(Project project, Node node) {
        Declaration dec;
        if (is Tree.Declaration node) {
            value dn = node;
            value container = dn.declarationModel.container;
            if (is Declaration container) {
                dec = container;
            } else {
                return;
            }
        } else {
            assert(is Declaration scope = node.scope);
            dec = scope;
        }
        addAddAnnotationProposal(node, "abstract", "Make Abstract", dec, project);
    }
    
    shared void addMakeVariableProposal(Project project, Node node) {
        Tree.Term term;
        if (is Tree.AssignmentOp node) {
            term = node.leftTerm;
        } else if (is Tree.UnaryOperatorExpression node) {
            term = node.term;
        } else if (is Tree.MemberOrTypeExpression node) {
            term = node;
        } else if (is Tree.SpecifierStatement node) {
            term = node.baseMemberExpression;
        } else {
            return;
        }
        
        if (is Tree.MemberOrTypeExpression term) {
            if (is Value dec = term.declaration) {
                if (!exists od = dec.originalDeclaration) {
                    addAddAnnotationProposal(node, "variable", "Make Variable", dec, project);
                }
            }
        }
    }
    
    shared void addMakeVariableDecProposal(Project project, Tree.CompilationUnit cu, Node node) {
        assert (is Tree.SpecifierOrInitializerExpression sie = node);
        class GetInitializedVisitor() extends Visitor() {
            
            shared variable Value? dec = null;
            
            shared actual void visit(Tree.AttributeDeclaration that) {
                super.visit(that);
                if (that.specifierOrInitializerExpression == sie) {
                    dec = that.declarationModel;
                }
            }
        }
        value v = GetInitializedVisitor();
        (v of Visitor).visit(cu);
        addAddAnnotationProposal(node, "variable", "Make Variable", v.dec, project);
    }


    
    Declaration annotatedNode(Node node) {
        Declaration dec;
        if (is Tree.Declaration node) {
            value dn = node;
            dec = dn.declarationModel;
        } else {
            assert (is Declaration scope = node.scope);
            dec = scope;
        }
        return dec;
    }
    
    shared void addMakeDefaultProposal(Project project, Node node) {
        variable Declaration d;
        if (is Tree.Declaration node) {
            value decNode = node;
            d = decNode.declarationModel;
        }
        if (is Tree.SpecifierStatement node) {
            value specNode = node;
            d = specNode.refined;
        } else if (is Tree.BaseMemberExpression node) {
            value bme = node;
            d = bme.declaration;
        } else {
            return;
        }
        if (d.classOrInterfaceMember) {
            assert (is ClassOrInterface container = d.container);
            value rds = container.getInheritedMembers(d.name);
            variable Declaration? rd = null;
            if (rds.empty) {
                rd = d;
            } else {
                for (r in CeylonIterable(rds)) {
                    if (!r.default) {
                        rd = r;
                        break;
                    }
                }
            }
            if (exists _rd = rd) {
                addAddAnnotationProposal(node, "default", "Make Default", _rd, project);
            }
        }
    }
    
    void addAddAnnotationProposal(Node? node, String annotation, String desc,
        Referenceable? dec, Project project) {
        
        if (exists dec, !(node is Tree.MissingDeclaration)) {
            Unit? u = dec.unit;
            // TODO
            //if (is EditedSourceFile u) {
            //    value esf = u;
            //    u = esf.originalSourceFile;
            //}
            for (unit in getUnits(project)) {
                if (exists u, u.equals(unit.unit)) {
                    value fdv = FindDeclarationNodeVisitor(dec);
                    // TODO use CorrectionUtil.getRootNode
                    unit.compilationUnit.visit(fdv);
                    value decNode = fdv.declarationNode;
                    if (exists decNode) {
                        addAddAnnotationProposal2(annotation, desc, dec, unit, node, decNode);
                    }
                    break;
                }
            }
        }
    }
    
    void addAddAnnotationProposal2(String annotation, String desc, Referenceable dec,
        PhasedUnit unit, Node? node, Tree.StatementOrArgument decNode) {
        value change = newTextChange(unit);
        initMultiEditChange(change);
        
        TextEdit edit = createReplaceAnnotationEdit(annotation, node, change)
                else createInsertAnnotationEdit(annotation, decNode,
            getDocumentForChange(change));
        
        addEditToChange(change, edit);
        
        createExplicitTypeEdit(decNode, change);
        
        Region? selection;
        value startOffset = getTextEditOffset(edit);
        if (exists node, node.unit.equals(decNode.unit)) {
            selection = newRegion(startOffset, annotation.size);
        } else {
            selection = null;
        }
        
        newAddAnnotationQuickFix(dec, annotation, description(annotation, dec), startOffset,
            change, selection);
    }
    
    void createExplicitTypeEdit(Tree.StatementOrArgument decNode, TextChange change) {
        if (decNode is Tree.TypedDeclaration, !(decNode is Tree.ObjectDefinition)) {
            assert (is Tree.TypedDeclaration tdNode = decNode);
            value type = tdNode.type;
            if (exists t = type.token, (type is Tree.FunctionModifier || type is Tree.ValueModifier)) {
                Type? it = type.typeModel;
                if (exists it, !(it.declaration is UnknownType)) {
                    value explicitType = it.asString();
                    addEditToChange(change, newReplaceEdit(type.startIndex.intValue(),
                            type.text.size, explicitType));
                }
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
                value td = container;
                variable String? name = td.name;
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
        value annotationList = getAnnotationList(node);
        if (exists annotationList) {
            for (ann in CeylonIterable(annotationList.annotations)) {
                if (exists id = getAnnotationIdentifier(ann), id == toRemove) {
                    value start = ann.startIndex.intValue();
                    value length = ann.endIndex.intValue() - start;
                    return newReplaceEdit(start, length, annotation);
                }
            }
        }
        return null;
    }
    
    shared InsertEdit createInsertAnnotationEdit(String newAnnotation, Node node, IDocument doc) {
        value newAnnotationName = getAnnotationWithoutParam(newAnnotation);
        variable Tree.Annotation? prevAnnotation = null;
        variable Tree.Annotation? nextAnnotation = null;
        value annotationList = getAnnotationList(node);
        if (exists annotationList) {
            for (annotation in CeylonIterable(annotationList.annotations)) {
                if (exists id = getAnnotationIdentifier(annotation),
                    isAnnotationAfter(newAnnotationName, id)) {
                    prevAnnotation = annotation;
                } else if (!exists n = nextAnnotation) {
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
                value tdn = node;
                nextNodeStartIndex = tdn.type.startIndex.intValue();
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
                newAnnotationText.append(indents.getDefaultLineDelimiter(doc));
                newAnnotationText.append(indents.getIndent(node, doc));
                newAnnotationText.append(newAnnotation);
            } else {
                newAnnotationOffset = nextNodeStartIndex;
                newAnnotationText.append(newAnnotation);
                newAnnotationText.append(indents.getDefaultLineDelimiter(doc));
                newAnnotationText.append(indents.getIndent(node, doc));
            }
        } else {
            newAnnotationOffset = nextNodeStartIndex;
            newAnnotationText.append(newAnnotation);
            newAnnotationText.append(" ");
        }
        return newInsertEdit(newAnnotationOffset, newAnnotationText.string);
    }
    
    shared Tree.AnnotationList? getAnnotationList(Node? node) {
        Tree.AnnotationList? annotationList;
        if (is Tree.Declaration node) {
            value tdn = node;
            annotationList = tdn.annotationList;
        } else if (is Tree.ModuleDescriptor node) {
            value mdn = node;
            annotationList = mdn.annotationList;
        } else if (is Tree.PackageDescriptor node) {
            value pdn = node;
            annotationList = pdn.annotationList;
        } else if (is Tree.Assertion node) {
            value an = node;
            annotationList = an.annotationList;
        } else {
            annotationList = null;
        }
        return annotationList;
    }
    
    shared String? getAnnotationIdentifier(Tree.Annotation? annotation) {
        variable String? annotationName = null;
        if (exists annotation) {
            value primary = annotation.primary;
            if (is Tree.BaseMemberExpression primary) {
                value bme = primary;
                annotationName = bme.identifier.text;
            }
        }
        return annotationName;
    }
    
    String getAnnotationWithoutParam(String annotation) {
        if (exists index = annotation.firstOccurrence('(')) {
            return annotation.span(0, index).trimmed;
        }
        
        if (exists index = annotation.firstOccurrence('"')) {
            return annotation.span(0, index).trimmed;
        }
        
        if (exists index = annotation.firstOccurrence(' ')) {
            return annotation.span(0, index).trimmed;
        }
        return annotation.trimmed;
    }
    
    Boolean isAnnotationAfter(String annotation1, String annotation2) {
        value index1 = annotationsOrder.firstIndexWhere(annotation1.equals) else 0;
        value index2 = annotationsOrder.firstIndexWhere(annotation1.equals) else 0;
        return index1 >= index2;
    }
    
    Boolean isAnnotationOnSeparateLine(String annotation) {
        return annotationsOnSeparateLine.contains(annotation);
    }
    
    shared void addMakeActualDecProposal(Project project, Node node) {
        value dec = annotatedNode(node);
        value shared = dec.shared;
        addAddAnnotationProposal(node, if (shared) then "actual" else "shared actual",
            if (shared) then "Make Actual" else "Make Shared Actual", dec, project);
    }
    
    shared void addMakeSharedProposalForSupertypes(Project project, Node node) {
        if (is Tree.ClassOrInterface node) {
            value cin = node;
            value ci = cin.declarationModel;
            Type? extendedType = ci.extendedType;
            if (exists extendedType) {
                addMakeSharedProposal2(project, extendedType.declaration);
                for (typeArgument in CeylonIterable(extendedType.typeArgumentList)) {
                    addMakeSharedProposal2(project, typeArgument.declaration);
                }
            }
            JList<Type>? satisfiedTypes = ci.satisfiedTypes;
            if (exists satisfiedTypes) {
                for (satisfiedType in CeylonIterable(satisfiedTypes)) {
                    addMakeSharedProposal2(project, satisfiedType.declaration);
                    for (typeArgument in CeylonIterable(satisfiedType.typeArgumentList)) {
                        addMakeSharedProposal2(project, typeArgument.declaration);
                    }
                }
            }
        }
    }
    
    shared void addMakeRefinedSharedProposal(Project project, Node node) {
        if (is Tree.Declaration node) {
            value tdn = node;
            value refined = tdn.declarationModel.refinedDeclaration;
            if (refined.default || refined.formal) {
                addMakeSharedProposal2(project, refined);
            } else {
                addAddAnnotationProposal(node, "shared default", "Make Shared Default", refined, project);
            }
        }
    }

    shared void addMakeSharedProposal(Project project, Node node) {
        variable Referenceable? dec = null;
        variable JList<Type>? typeArgumentList = null;
        if (is Tree.StaticMemberOrTypeExpression node) {
            value qmte = node;
            dec = qmte.declaration;
        } else if (is Tree.SimpleType node) {
            value st = node;
            dec = st.declarationModel;
        } else if (is Tree.OptionalType node) {
            value ot = node;
            if (is Tree.SimpleType st = ot.definiteType) {
                dec = st.declarationModel;
            }
        } else if (is Tree.IterableType node) {
            value it = node;
            if (is Tree.SimpleType st = it.elementType) {
                dec = st.declarationModel;
            }
        } else if (is Tree.SequenceType node) {
            value qt = node;
            if (is Tree.SimpleType st = qt.elementType) {
                dec = st.declarationModel;
            }
        } else if (is Tree.ImportMemberOrType node) {
            value imt = node;
            dec = imt.declarationModel;
        } else if (is Tree.ImportPath node) {
            value ip = node;
            dec = ip.model;
        } else if (is Tree.TypedDeclaration node) {
            if (exists td = node.declarationModel) {
                value pt = td.type;
                dec = pt.declaration;
                typeArgumentList = pt.typeArgumentList;
            }
        } else if (is Tree.Parameter node) {
            value parameter = node;
            if (exists param = parameter.parameterModel, exists p = param.type) {
                value pt = param.type;
                dec = pt.declaration;
                typeArgumentList = pt.typeArgumentList;
            }
        }
        addMakeSharedProposal2(project, dec);
        if (exists tal = typeArgumentList) {
            for (typeArgument in CeylonIterable(tal)) {
                addMakeSharedProposal2(project, typeArgument.declaration);
            }
        }
    }
    
    void addMakeSharedProposal2(Project project, Referenceable? ref) {
        if (exists ref) {
            if (is TypedDeclaration|ClassOrInterface|TypeAlias ref) {
                if (!(ref).shared) {
                    addAddAnnotationProposal(null, "shared", "Make Shared", ref, project);
                }
            } else if (is Package ref) {
                if (!ref.shared) {
                    addAddAnnotationProposal(null, "shared", "Make Shared", ref, project);
                }
            }
        }
    }
    
    shared void addMakeSharedDecProposal(Project project, Node node) {
        if (is Tree.Declaration node) {
            value dn = node;
            addAddAnnotationProposal(node, "shared", "Make Shared", dn.declarationModel, project);
        }
    }
}
