import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.imports {
    AbstractModuleImportUtil
}
import com.redhat.ceylon.ide.common.util {
    FindDeclarationNodeVisitor,
    types
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

shared interface AddAnnotationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newAddAnnotationQuickFix(Referenceable dec, String text, String desc, Integer offset,
        TextChange change, Region? selection, Data data);

    shared formal void newCorrectionQuickFix(String desc, TextChange change, Region? selection);
    
    shared formal AbstractModuleImportUtil<IFile,Project,IDocument,InsertEdit,TextEdit,TextChange> moduleImportUtil;
    
    value annotationsOrder => ["doc", "throws", "see", "tagged", "shared", "abstract",
        "actual", "formal", "default", "variable"];
    
    value annotationsOnSeparateLine => ["doc", "throws", "see", "tagged"];
    
    shared void addMakeFormalDecProposal(Project project, Node node, Data data) {
        value dec = annotatedNode(node);
        value ann = if (dec.shared) then "formal" else "shared formal";
        value desc = if (dec.shared) then "Make Formal" else "Make Shared Formal";
        addAddAnnotationProposal(node, ann, desc, dec, project, data);
    }

    shared void addMakeAbstractDecProposal(Node node, Project p, Data data) {
        value dec = annotatedNode(node);
        if (is Class dec) {
            addAddAnnotationProposal(node, "abstract", "Make Abstract", dec, p, data);
        }
    }
    
    shared void addMakeNativeProposal(Project project, Node node, IFile file, Data data) {
        if (is Tree.ImportPath node) {
            object extends Visitor() {
                shared actual void visit(Tree.ModuleDescriptor that) {
                    value ip = node;
                    assert(is Module \imodule = ip.model);
                    value backends = \imodule.nativeBackends;
                    value change = newTextChange("Declare Module Native", file);
                    value annotation = StringBuilder();
                    moduleImportUtil.appendNative(annotation, backends);
                    addEditToChange(change, newInsertEdit(that.startIndex.intValue(), annotation.string + " "));
                    newCorrectionQuickFix("Declare module '" + annotation.string + "'", change, null);
                    
                    super.visit(that);
                }
                
                shared actual void visit(Tree.ImportModule that) {
                    if (that.importPath == node) {
                        assert (is Module \imodule = that.importPath.model);
                        value backends = \imodule.nativeBackends;
                        value change = newTextChange("Declare Import Native", file);
                        value annotation = StringBuilder();
                        moduleImportUtil.appendNative(annotation, backends);
                        addEditToChange(change, newInsertEdit(that.startIndex.intValue(), annotation.string + " "));
                        newCorrectionQuickFix("Declare import '" + annotation.string + "'", change, null);
                    }
                    
                    super.visit(that);
                }
            }.visit(data.rootNode);
        }
    }

    shared void addMakeContainerAbstractProposal(Project project, Node node, Data data) {
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
        addAddAnnotationProposal(node, "abstract", "Make Abstract", dec, project, data);
    }
    
    shared void addMakeVariableProposal(Project project, Node node, Data data) {
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
            addAddAnnotationProposal(node, "variable", "Make Variable", dec, project, data);
            if (dec.classMember) {
                addAddAnnotationProposal(node, "late", "Make Late", dec, project, data);
            }
        }
    }

    shared void addMakeVariableDeclarationProposal(Project project, Data data,
        Tree.Declaration node) {
        
        if (is Value dec = node.declarationModel,
            is Tree.AttributeDeclaration node,
            !dec.variable,
            !dec.transient) {

            addAddAnnotationProposal(node, "variable", "Make Variable",
                    dec, project, data);
        }
    }
    
    shared void addMakeVariableDecProposal(Project project, Data data) {
        assert (is Tree.SpecifierOrInitializerExpression sie = data.node);
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
        (v of Visitor).visit(data.rootNode);
        addAddAnnotationProposal(data.node, "variable", "Make Variable", v.dec, project, data);
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
    
    shared void addMakeDefaultProposal(Project project, Node node, Data data) {
        variable Declaration? d;
        if (is Tree.Declaration node) {
            value decNode = node;
            //get the supertype declaration we're refining
            d = types.getRefinedDeclaration(decNode.declarationModel);
        } else if (is Tree.SpecifierStatement node) {
            value specNode = node;
            //get the supertype declaration we're referencing
            d = specNode.refined;
        /*} else if (is Tree.BaseMemberExpression node) {
            value bme = node;
            d = bme.declaration;
        */
        } else {
            return;
        }
        if (exists _d = d, _d.classOrInterfaceMember) {
            addAddAnnotationProposal(node, "default",
                "Make default", d, project, data);

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
    
    shared void addMakeDefaultDecProposal(Project project, Node node, Data data) {
        value dec = annotatedNode(node);
        addAddAnnotationProposal(node,
            if (dec.shared) then "default" else "shared default",
            if (dec.shared) then "Make Default" else "Make Shared Default",
            dec, project, data);
    }

    
    void addAddAnnotationProposal(Node? node, String annotation, String desc,
        Referenceable? dec, Project project, Data data) {
        
        if (exists dec, !(node is Tree.MissingDeclaration),
            exists phasedUnit = getPhasedUnit(dec.unit, data)) {

            value fdv = FindDeclarationNodeVisitor(dec);
            phasedUnit.compilationUnit.visit(fdv);
            value decNode = fdv.declarationNode;
            if (exists decNode) {
                addAddAnnotationProposal2(annotation, desc, dec, phasedUnit,
                    node, decNode, data);
            }
        }
    }
    
    void addAddAnnotationProposal2(String annotation, String desc, Referenceable dec,
        PhasedUnit unit, Node? node, Tree.StatementOrArgument decNode, Data data) {
        value change = newTextChange(desc, unit);
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
            change, selection, data);
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
        if (exists annotationList = getAnnotationList(node)) {
            for (ann in annotationList.annotations) {
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
        if (exists annotationList = getAnnotationList(node)) {
            for (annotation in annotationList.annotations) {
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
    
    shared void addMakeActualDecProposal(Project project, Node node, Data data) {
        value dec = annotatedNode(node);
        value shared = dec.shared;
        addAddAnnotationProposal(node, if (shared) then "actual" else "shared actual",
            if (shared) then "Make Actual" else "Make Shared Actual", dec, project, data);
    }
    
    shared void addMakeSharedProposalForSupertypes(Project project, Node node, Data data) {
        if (is Tree.ClassOrInterface node) {
            value cin = node;
            value ci = cin.declarationModel;
            if (exists extendedType = ci.extendedType) {
                addMakeSharedProposal2(project, extendedType.declaration, data);
                for (typeArgument in extendedType.typeArgumentList) {
                    addMakeSharedProposal2(project, typeArgument.declaration, data);
                }
            }
            if (exists satisfiedTypes = ci.satisfiedTypes) {
                for (satisfiedType in satisfiedTypes) {
                    addMakeSharedProposal2(project, satisfiedType.declaration, data);
                    for (typeArgument in satisfiedType.typeArgumentList) {
                        addMakeSharedProposal2(project, typeArgument.declaration, data);
                    }
                }
            }
        }
    }
    
    shared void addMakeRefinedSharedProposal(Project project, Node node, Data data) {
        if (is Tree.Declaration node) {
            value tdn = node;
            value refined = tdn.declarationModel.refinedDeclaration;
            if (refined.default || refined.formal) {
                addMakeSharedProposal2(project, refined, data);
            } else {
                addAddAnnotationProposal(node, "shared default", "Make Shared Default", refined, project, data);
            }
        }
    }

    shared void addMakeSharedProposal(Project project, Node node, Data data) {
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
        addMakeSharedProposal2(project, dec, data);
        if (exists tal = typeArgumentList) {
            for (typeArgument in tal) {
                addMakeSharedProposal2(project, typeArgument.declaration, data);
            }
        }
    }
    
    void addMakeSharedProposal2(Project project, Referenceable? ref, Data data) {
        if (exists ref) {
            if (is TypedDeclaration|ClassOrInterface|TypeAlias ref) {
                if (!(ref).shared) {
                    addAddAnnotationProposal(null, "shared", "Make Shared", ref, project, data);
                }
            } else if (is Package ref) {
                if (!ref.shared) {
                    addAddAnnotationProposal(null, "shared", "Make Shared", ref, project, data);
                }
            }
        }
    }
    
    shared void addMakeSharedDecProposal(Project project, Node node, Data data) {
        if (is Tree.Declaration node) {
            value dn = node;
            addAddAnnotationProposal(node, "shared", "Make Shared", dn.declarationModel, project, data);
        }
    }
}
