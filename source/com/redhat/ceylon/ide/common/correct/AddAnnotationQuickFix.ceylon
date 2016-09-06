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
import com.redhat.ceylon.ide.common.model {
    AnyModifiableSourceFile
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
    
    value annotationsOrder => ["doc", "throws", "see", "tagged", "shared", "abstract",
    "actual", "formal", "default", "variable"];
    
    value annotationsOnSeparateLine => ["doc", "throws", "see", "tagged"];
    
    shared void addMakeFormalDecProposal(Node node, QuickFixData data) {
        value dec = annotatedNode(node);
        value shared = dec.shared;
        addAddAnnotationProposal {
            node = node;
            annotation = shared then "formal" else "shared formal";
            desc = shared then "Make Formal" else "Make Shared Formal";
            dec = dec;
            data = data;
        };
    }
    
    shared void addMakeAbstractDecProposal(Node node, QuickFixData data) {
        if (is Class dec = annotatedNode(node)) {
            addAddAnnotationProposal {
                node = node;
                annotation = "abstract";
                desc = "Make Abstract";
                dec = dec;
                data = data;
            };
        }
    }
    
    shared void addMakeNativeProposal(Node node, QuickFixData data) {
        if (is Tree.ImportPath node) {
            object extends Visitor() {
                shared actual void visit(Tree.ModuleDescriptor that) {
                    assert(is Module m = node.model);
                    value backends = m.nativeBackends;
                    value change = platformServices.document.createTextChange {
                        name = "Declare Module Native";
                        input = data.phasedUnit;
                    };
                    value annotation = StringBuilder();
                    moduleImportUtil.appendNative(annotation, backends);
                    change.addEdit(InsertEdit {
                        start = that.startIndex.intValue();
                        text = annotation.string + " ";
                    });
                    data.addQuickFix {
                        description = "Declare module '``annotation``'";
                        change = change;
                    };
                    
                    super.visit(that);
                }
                
                shared actual void visit(Tree.ImportModule that) {
                    if (that.importPath == node) {
                        assert (is Module m = that.importPath.model);
                        value backends = m.nativeBackends;
                        value change = platformServices.document.createTextChange {
                            name = "Declare Import Native";
                            input = data.phasedUnit;
                        };
                        value annotation = StringBuilder();
                        moduleImportUtil.appendNative(annotation, backends);
                        change.addEdit(InsertEdit {
                            start = that.startIndex.intValue();
                            text = annotation.string + " ";
                        });
                        data.addQuickFix {
                            description = "Declare import '``annotation``'";
                            change = change;
                        };
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
        addAddAnnotationProposal {
            node = node;
            annotation = "abstract";
            desc = "Make Abstract";
            dec = dec;
            data = data;
        };
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
            addAddAnnotationProposal {
                node = node;
                annotation = annotation.string;
                desc = "Make Native";
                dec = dec;
                data = data;
            };
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
            addAddAnnotationProposal {
                node = node;
                annotation = "variable";
                desc = "Make Variable";
                dec = dec;
                data = data;
            };
            if (dec.classMember) {
                addAddAnnotationProposal {
                    node = node;
                    annotation = "late";
                    desc = "Make Late";
                    dec = dec;
                    data = data;
                };
            }
        }
    }
    
    shared void addMakeVariableDeclarationProposal(QuickFixData data,
        Tree.Declaration node) {
        
        if (is Value dec = node.declarationModel,
            is Tree.AttributeDeclaration node,
            !dec.variable,
            !dec.transient) {
            
            addAddAnnotationProposal {
                node = node;
                annotation = "variable";
                desc = "Make Variable";
                dec = dec;
                data = data;
            };
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
        addAddAnnotationProposal {
            node = data.node;
            annotation = "variable";
            desc = "Make Variable";
            dec = dec;
            data = data;
        };
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
        Declaration? d;
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
        if (exists d, d.classOrInterfaceMember) {
            addAddAnnotationProposal {
                node = node;
                annotation = "default";
                desc = "Make default";
                dec = d;
                data = data;
            };
            
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
        addAddAnnotationProposal {
            node = node;
            annotation = dec.shared then "default" else "shared default";
            desc = dec.shared then "Make Default" else "Make Shared Default";
            dec = dec;
            data = data;
        };
    }
    
    
    void addAddAnnotationProposal(Node? node, String annotation, String desc,
        Referenceable? dec, QuickFixData data) {
        
        if (exists dec, !node is Tree.MissingDeclaration,
            is AnyModifiableSourceFile unit = dec.unit,
            exists phasedUnit = unit.phasedUnit,
            exists rootNode = unit.compilationUnit) {
            value fdv = FindDeclarationNodeVisitor(dec);
            rootNode.visit(fdv);
            if (exists decNode = fdv.declarationNode) {
                addAddAnnotationProposal2 {
                    annotation = annotation;
                    desc = desc;
                    dec = dec;
                    unit = phasedUnit;
                    node = node;
                    decNode = decNode;
                    data = data;
                };
            }
        }
    }
    
    void addAddAnnotationProposal2(String annotation, String desc, Referenceable dec,
        PhasedUnit unit, Node? node, Tree.StatementOrArgument decNode, QuickFixData data) {
        value change 
                = platformServices.document.createTextChange {
            name = desc;
            input = unit;
        };
        change.initMultiEdit();
        
        value edit 
                = createReplaceAnnotationEdit {
                    annotation = annotation;
                    node = node;
                    change = change;
                }
                else createInsertAnnotationEdit {
                    newAnnotation = annotation;
                    node = decNode;
                    doc = change.document;
                };
        
        change.addEdit(edit);
        
        createExplicitTypeEdit(decNode, change);
        value selection = 
                if (exists node, node.unit==decNode.unit) 
                then DefaultRegion {
                    start = edit.start;
                    length = annotation.size;
                } 
                else null;
        
        data.addQuickFix {
            description = description(annotation, dec);
            change = change;
            selection = selection;
        };
    }
    
    void createExplicitTypeEdit(Tree.StatementOrArgument decNode, TextChange change) {
        if (is Tree.TypedDeclaration decNode, 
            !decNode is Tree.ObjectDefinition,
            is Tree.FunctionModifier|Tree.ValueModifier type 
                    = decNode.type, 
            type.token exists, 
            exists it = type.typeModel, !it.unknown) {
            change.addEdit(ReplaceEdit {
                start = type.startIndex.intValue();
                length = type.text.size;
                text = it.asString();
            });
        }
    }
    
    String description(String annotation, Referenceable dec) {
        switch (dec)
        case (is Declaration) {
            String containerDesc;
            if (is TypeDeclaration container = dec.container) {
                if (!container.name exists) {
                    if (is Constructor container, 
                        is Declaration cont = container.container) {
                        containerDesc = " in '``cont.name``'";
                    }
                    else {
                        containerDesc = "";
                    }
                }
                else {
                    containerDesc = " in '``container.name``'";
                }
            }
            else {
                containerDesc = "";
            }
            if (exists name = dec.name) {
                return "Make '``name``' " + annotation + containerDesc;
            }    
            else if (ModelUtil.isConstructor(dec)) {
                return "Make default constructor " + annotation + containerDesc;
            }
            else {
                return "Make " + annotation;
            }
        }
        case (is Package) {
            return "Make package '``dec.nameAsString``' " + annotation;
        }
        else {
            assert (false);
        }
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
                if (exists id = getAnnotationIdentifier(ann), 
                    id == toRemove) {
                    value start = ann.startIndex.intValue();
                    value length = ann.endIndex.intValue() - start;
                    return ReplaceEdit {
                        start = start;
                        length = length;
                        text = annotation;
                    };
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
            switch (node) 
            case (is Tree.AnyAttribute|Tree.AnyMethod) {
                nextNodeStartIndex = node.type.startIndex.intValue();
            } 
            case (is Tree.ObjectDefinition) {
                assert (is CommonToken token = node.mainToken);
                nextNodeStartIndex = token.startIndex;
            }
            case (is Tree.ClassOrInterface) {
                assert (is CommonToken token = node.mainToken);
                nextNodeStartIndex = token.startIndex;
            }
            else {
                nextNodeStartIndex = node.startIndex.intValue();
            }
        }
        
        Integer newAnnotationOffset;
        value newAnnotationText = StringBuilder();
        if (isAnnotationOnSeparateLine(newAnnotationName), 
            !node is Tree.Parameter) {
            if (exists ann = prevAnnotation, 
                exists id = getAnnotationIdentifier(ann),
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
        return InsertEdit {
            start = newAnnotationOffset;
            text = newAnnotationText.string;
        };
    }
    
    shared Tree.AnnotationList? getAnnotationList(Node? node) {
        switch (node)
        case (is Tree.Declaration) {
            return node.annotationList;
        }
        case (is Tree.ModuleDescriptor) {
            return node.annotationList;
        }
        case (is Tree.PackageDescriptor) {
            return node.annotationList;
        }
        case (is Tree.Assertion) {
            return node.annotationList;
        }
        else {
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
        addAddAnnotationProposal {
            node = node;
            annotation = if (shared) then "actual" else "shared actual";
            desc = if (shared) then "Make Actual" else "Make Shared Actual";
            dec = dec;
            data = data;
        };
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
                addAddAnnotationProposal {
                    node = node;
                    annotation = "shared default";
                    desc = "Make Shared Default";
                    dec = refined;
                    data = data;
                };
            }
        }
    }
    
    shared void addMakeSharedProposal(Node node, QuickFixData data) {
        Referenceable? dec;
        JList<Type>? typeArguments;
        switch (node)
        case (is Tree.StaticMemberOrTypeExpression) {
            dec = node.declaration;
            typeArguments = null;
        }
        case (is Tree.SimpleType) {
            dec = node.declarationModel;
            typeArguments = null;
        }
        case (is Tree.OptionalType) {
            if (is Tree.SimpleType st = node.definiteType) {
                dec = st.declarationModel;
                typeArguments = null;
            }
            else {
                return;
            }
        }
        case (is Tree.IterableType) {
            if (is Tree.SimpleType st = node.elementType) {
                dec = st.declarationModel;
                typeArguments = null;
            }
            else {
                return;
            }
        }
        case (is Tree.SequenceType) {
            if (is Tree.SimpleType st = node.elementType) {
                dec = st.declarationModel;
                typeArguments = null;
            }
            else {
                return;
            }
        }
        case (is Tree.ImportMemberOrType) {
            dec = node.declarationModel;
            typeArguments = null;
        }
        case (is Tree.ImportPath) {
            dec = node.model;
            typeArguments = null;
        }
        case (is Tree.TypedDeclaration) {
            if (exists td = node.declarationModel,
                exists pt = td.type) {
                dec = pt.declaration;
                typeArguments = pt.typeArgumentList;
            }
            else {
                return;
            }
        }
        case (is Tree.Parameter) {
            if (exists param = node.parameterModel, 
                exists pt = param.type) {
                dec = pt.declaration;
                typeArguments = pt.typeArgumentList;
            }
            else {
                return;
            }
        }
        else {
            return;
        }
        addMakeSharedProposal2(dec, data);
        if (exists typeArguments) {
            for (typeArgument in typeArguments) {
                addMakeSharedProposal2(typeArgument.declaration, data);
            }
        }
    }
    
    void addMakeSharedProposal2(Referenceable? ref, QuickFixData data) {
        switch (ref)
        case (is TypedDeclaration|ClassOrInterface|TypeAlias) {
            if (!ref.shared) {
                addAddAnnotationProposal {
                    node = null;
                    annotation = "shared";
                    desc = "Make Shared";
                    dec = ref;
                    data = data;
                };
            }
            else if (is ClassOrInterface container = ref.container) {
                if (!container.shared) {
                    addAddAnnotationProposal {
                        node = null;
                        annotation = "shared";
                        desc = "Make Shared";
                        dec = container;
                        data = data;
                    };
                }
            }
        }
        case (is Package) {
            if (!ref.shared) {
                addAddAnnotationProposal {
                    node = null;
                    annotation = "shared";
                    desc = "Make Shared";
                    dec = ref;
                    data = data;
                };
            }
        }
        else {}
    }
    
    shared void addMakeSharedDecProposal(Node node, QuickFixData data) {
        if (is Tree.Declaration node) {
            addAddAnnotationProposal {
                node = node;
                annotation = "shared";
                desc = "Make Shared";
                dec = node.declarationModel;
                data = data;
            };
        }
    }
    
    shared void addContextualAnnotationProposals(QuickFixData data, Tree.Declaration? decNode, 
        Integer offset) {
                
        if (exists decNode, 
            exists idNode = nodes.getIdentifyingNode(decNode)) {
            value doc = data.document;
            if (doc.getLineOfOffset(idNode.startIndex.intValue())
                != doc.getLineOfOffset(offset)) {
                return;
            }
            
            if (exists d = decNode.declarationModel) {
                if (is Tree.AttributeDeclaration decNode) {
                    addMakeVariableDeclarationProposal(data, decNode);
                }
                
                if (d.classOrInterfaceMember || d.toplevel, !d.shared) {
                    addMakeSharedDecProposal(decNode, data);
                }
                
                if (d.classOrInterfaceMember, !d.default, !d.formal) {
                    switch (decNode)
                    case (is Tree.AnyClass) {
                        addMakeDefaultDecProposal(decNode, data);
                    }
                    case (is Tree.AnyAttribute) {
                        addMakeDefaultDecProposal(decNode, data);
                    }
                    case (is Tree.AnyMethod) {
                        addMakeDefaultDecProposal(decNode, data);
                    }
                    else {}
                    
                    switch (decNode)
                    case (is Tree.ClassDefinition) {
                        addMakeFormalDecProposal(decNode, data);
                    }
                    case (is Tree.AttributeDeclaration) {
                        if (!decNode.specifierOrInitializerExpression exists &&
                            !decNode.declarationModel.parameter) {
                            addMakeFormalDecProposal(decNode, data);
                        }
                    }
                    case (is Tree.MethodDeclaration) {
                        if (!decNode.specifierExpression exists &&
                            !decNode.declarationModel.parameter) {
                            addMakeFormalDecProposal(decNode, data);
                        }
                    }
                    else {}
                }
            }
        }
    }
}
