import ceylon.collection {
    HashSet,
    HashMap,
    MutableMap,
    ArrayList,
    MutableList,
    TreeSet
}
import ceylon.language.meta.model {
    ClassOrInterface
}

import com.redhat.ceylon.compiler.typechecker.analyzer {
    AnalysisError
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Ast=Tree,
    AstAbstractNode=Node,
    Visitor,
    VisitorAdaptor,
    TreeUtil {
        formatPath,
        hasAnnotation,
        getNativeBackend
    },
    Message
}
import com.redhat.ceylon.model.typechecker.model {
    ModelDeclaration=Declaration,
    Function,
    ModuleImport,
    Module,
    Unit
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager {
        moduleDescriptorFileName=moduleFile,
        packageDescriptorFileName=packageFile
    },
    TypePrinter
}

import java.util {
    JList=List
}
import java.lang {
    Types {
        classForInstance
    }
}

shared interface NodeComparisonListener {
    shared formal void comparedNodes(String? oldNode, String? newNode, Ast.Declaration declaration, String attribute);
    shared formal void comparedDeclaration(Ast.Declaration declaration, Boolean hasStructuralChanges);
}


shared class DeltaBuilderFactory(
    Boolean compareAnalysisErrors = false) {

    variable value unknownCounter = 0;
    function unknownKey() => "<unknown_`` unknownCounter++ ``>";
    value producedTypeNamePrinter = TypePrinter(true, true, true, true, false, true, true);

    "Builds a [[model delta|AbstractDelta]] that describes the model differences
     between a [[reference PhasedUnit|buildDeltas.referencePhasedUnit]]
     and a [[changed PhasedUnit|buildDeltas.changedPhasedUnit]]
     related to the same file.

     In case of a regular compilation unit(not a descriptor), only the
     model elements visibile _outside_ the unit are considered.
     "
    shared CompilationUnitDelta buildDeltas(
        "Referenced phased unit, typically of central Ceylon model"
        PhasedUnit referencePhasedUnit,
        "Changed phased unit, typically a just-saved working copy"
        PhasedUnit changedPhasedUnit,
        "Listener that registers the detail of every structural node comparisons"
        NodeComparisonListener? nodeComparisonListener = null) {

        assert (exists unitFile = referencePhasedUnit.unitFile);
        if (unitFile.name == moduleDescriptorFileName) {
            return buildModuleDescriptorDeltas {
                referencePhasedUnit = referencePhasedUnit;
                changedPhasedUnit = changedPhasedUnit;
                nodeComparisonListener = nodeComparisonListener;
            };
        }

        if (unitFile.name == packageDescriptorFileName) {
            return buildPackageDescriptorDeltas {
                referencePhasedUnit = referencePhasedUnit;
                changedPhasedUnit = changedPhasedUnit;
                nodeComparisonListener = nodeComparisonListener;
            };
        }

        return buildCompilationUnitDeltas {
            referencePhasedUnit = referencePhasedUnit;
            changedPhasedUnit = changedPhasedUnit;
            nodeComparisonListener = nodeComparisonListener;
        };
    }

    ModuleDescriptorDelta buildModuleDescriptorDeltas(
            PhasedUnit referencePhasedUnit, PhasedUnit changedPhasedUnit,
            NodeComparisonListener? nodeComparisonListener) {
        if (exists oldDescriptor = referencePhasedUnit.compilationUnit?.moduleDescriptors?.get(0)) {
            value builder = ModuleDescriptorDeltaBuilder {
                oldNode = oldDescriptor;
                newNode = changedPhasedUnit.compilationUnit?.moduleDescriptors?.get(0);
                nodeComparisonListener = nodeComparisonListener;
            };
            return builder.buildDelta();
        } else {
            return InvalidModuleDescriptorDelta();
        }
    }

    PackageDescriptorDelta buildPackageDescriptorDeltas(
            PhasedUnit referencePhasedUnit, PhasedUnit changedPhasedUnit,
            NodeComparisonListener? nodeComparisonListener) {
        if (exists oldDescriptor = referencePhasedUnit.compilationUnit?.packageDescriptors?.get(0)) {
            value builder = PackageDescriptorDeltaBuilder {
                oldNode = oldDescriptor;
                newNode = changedPhasedUnit.compilationUnit?.packageDescriptors?.get(0);
                nodeComparisonListener = nodeComparisonListener;
            };
            return builder.buildDelta();
        } else {
            return InvalidPackageDescriptorDelta();
        }
    }

    RegularCompilationUnitDelta buildCompilationUnitDeltas(
            PhasedUnit referencePhasedUnit, PhasedUnit changedPhasedUnit,
            NodeComparisonListener? nodeComparisonListener) {
        value builder = RegularCompilationUnitDeltaBuilder {
            oldNode = referencePhasedUnit.compilationUnit;
            newNode = changedPhasedUnit.compilationUnit;
            nodeComparisonListener = nodeComparisonListener;
        };
        return builder.buildDelta();
    }

    String importedModuleName(Ast.ImportModule child) {
        Ast.ImportPath? importPath = child.importPath;
        Ast.QuotedLiteral? quotedLitteral = child.quotedLiteral;
        String moduleName;
        if (exists quotedLitteral) {
            moduleName = quotedLitteral.text;
        } else {
            if (exists importPath) {
                moduleName = formatPath(importPath.identifiers);
            } else {
                moduleName = unknownKey();
            }
        }
        return moduleName;
    }

    "Compares two message lists to see if they have the same errors.

     Because error messages contain identifiers which might have been aliased,
     it's difficult to tell if two errors are really the same error.
     At the moment, to avoid false positives, we consider any two message lists
     containing at least one error to be different...

     ... unless the [[compareAnalysisErrors]] parameter is true.

     (This method isn't useless, though: It ignores other kinds of messages.)"
    Boolean errorListsEquals(JList<Message> these, JList<Message> those)
        => let (theseAnalysisErrors
                    = TreeSet {
                        byIncreasing(Message.message);
                        for (element in these)
                        if (element is AnalysisError) element
                    },
                thoseAnalysisErrors
                    = TreeSet {
                        byIncreasing(Message.message);
                        for (element in those)
                        if (element is AnalysisError) element
                    })
            if (compareAnalysisErrors)
                then theseAnalysisErrors == thoseAnalysisErrors
                else theseAnalysisErrors.empty
                  && thoseAnalysisErrors.empty;

    interface AbstractDeltaBuilder {
        shared formal AbstractDelta buildDelta();
    }
    
    abstract class DeltaBuilder<ParentNode, ChildNode>(ParentNode oldNode, ParentNode? newNode)
            satisfies AbstractDeltaBuilder
            given ParentNode of Ast.Declaration
                              | Ast.SpecifierStatement
                              | Ast.CompilationUnit
                              | Ast.ModuleDescriptor
                              | Ast.ImportModule
                              | Ast.PackageDescriptor
            given ChildNode of Ast.Statement
                             | Ast.CompilationUnit
                             | Ast.ModuleDescriptor
                             | Ast.ImportModule
                             | Ast.PackageDescriptor {

//        shared alias ParentNode => ParentNodeType;// & AstAbstractNode;
//        shared alias ChildNode => ChildNodeType;// & AstAbstractNode;
        
        shared formal [ChildNode*] getChildren(ParentNode astNode);

        shared formal void registerRemovedChange();
        shared formal void calculateLocalChanges();
        shared formal void manageChildDelta(ChildNode oldChild, ChildNode? newChild);
        shared formal void registerMemberAddedChange(ChildNode newChild);

        shared default void recurse() {
            if (newNode is Null) {
                registerRemovedChange();
                return;
            }
            assert (exists newNode);

            calculateLocalChanges();

            value oldChildren = getChildren(oldNode);
            value newChildren = getChildren(newNode);

            if (newChildren nonempty || oldChildren nonempty) {
                value allChildrenSet = HashSet<String>();

                function toMap([ChildNode*] children) {
                    MutableMap<String,ChildNode>? childrenSet;
                    if (nonempty children) {
                        childrenSet = HashMap<String,ChildNode>();
                        assert (exists childrenSet);
                        for (child in children) {
                            String childKey;
                            switch (child)
                            case (is Ast.Declaration) {
                                value model = child.declarationModel else null;
                                childKey = if (exists model) 
                                then "``classForInstance(model).simpleName``[``model.qualifiedNameString``]"
                                else unknownKey();
                            }
                            case (is Ast.SpecifierStatement) {
                                value model = child.declaration else null;
                                childKey = if (exists model) 
                                then "=>``classForInstance(model).simpleName``[``model.qualifiedNameString``]"
                                else unknownKey();
                            }
                            case (is Ast.ModuleDescriptor) {
                                childKey = child.unit?.fullPath else unknownKey();
                            }
                            case (is Ast.PackageDescriptor) {
                                childKey = child.unit?.fullPath  else unknownKey();
                            }
                            case (is Ast.CompilationUnit) {
                                childKey = child.unit?.fullPath else unknownKey();
                            }
                            case (is Ast.ImportModule) {
                                childKey = importedModuleName(child) + "/"
                                         + (child.version?.text?.trim('"'.equals) else unknownKey());
                            } else {
                                continue;
                            }

                            allChildrenSet.add(childKey);
                            childrenSet[childKey] = child;
                        }
                    } else {
                        childrenSet = null;
                    }
                    return childrenSet;
                }

                value oldChildrenSet = toMap(oldChildren);
                value newChildrenSet = toMap(newChildren);

                for (keyChild in allChildrenSet) {
                    value oldChild = oldChildrenSet?.get(keyChild);
                    value newChild = newChildrenSet?.get(keyChild);
                    if (exists oldChild) {
                        manageChildDelta(oldChild, newChild);
                    } else {
                        assert (exists newChild);
                        registerMemberAddedChange(newChild);
                    }
                }
            }
        }
    }

    class PackageDescriptorDeltaBuilder(Ast.PackageDescriptor oldNode,
                                        Ast.PackageDescriptor? newNode,
                                        NodeComparisonListener? nodeComparisonListener)
            extends DeltaBuilder<Ast.PackageDescriptor, Nothing>(oldNode, newNode) {
        variable PackageDescriptorDelta.PossibleChange? change = null;

        shared actual PackageDescriptorDelta buildDelta() {
            recurse();
            return object satisfies PackageDescriptorDelta {
                changedElement => oldNode.unit.\ipackage;
                changes => if (exists existingChange = change) then [existingChange] else [];
                equals(Object that) => (super of AbstractDelta).equals(that);
            };
        }

        manageChildDelta(Nothing oldChild, Nothing? newChild) => noop();
 
        registerMemberAddedChange(Nothing newChild) => noop();

        registerRemovedChange() => noop();

        shared actual void calculateLocalChanges() {
            assert (exists newNode);
            if (formatPath(oldNode.importPath.identifiers)
                != formatPath(newNode.importPath.identifiers)) {
                change = structuralChange;
                return;
            }

            function isShared(Ast.PackageDescriptor descriptor)
                    => hasAnnotation(descriptor.annotationList, "shared", descriptor.unit);

            value sharedBefore = isShared(oldNode);
            value sharedNow = isShared(newNode);

            if (sharedBefore && !sharedNow) {
                change = madeInvisibleOutsideScope;
            }
            if (!sharedBefore && sharedNow) {
                change = madeVisibleOutsideScope;
            }
        }

        getChildren(Ast.PackageDescriptor astNode) => [];
    }

    function sameBackend(Ast.AnnotationList? oldList, Unit? oldUnit,
                         Ast.AnnotationList? newList, Unit? newUnit)
            => let (oldNative = getNativeBackend(oldList, oldUnit),
                    newNative = getNativeBackend(newList, newUnit))
                        oldNative == newNative;

    class ModuleDescriptorDeltaBuilder(Ast.ModuleDescriptor oldNode, 
                                       Ast.ModuleDescriptor? newNode, 
                                       NodeComparisonListener? nodeComparisonListener)
            extends DeltaBuilder<Ast.ModuleDescriptor, Ast.ImportModule>(oldNode, newNode) {
        variable value changes = ArrayList<ModuleDescriptorDelta.PossibleChange>();
        variable value childrenDeltas = ArrayList<ModuleImportDelta>();
        value oldModule
                = if (is Module model = oldNode.importPath?.model)
                then model else null;

        shared actual ModuleDescriptorDelta buildDelta() {
            recurse();
            return object satisfies ModuleDescriptorDelta {
                changedElement => oldModule;
                changes => outer.changes;
                equals(Object that) => (super of AbstractDelta).equals(that);
                childrenDeltas => outer.childrenDeltas;
            };
        }

        shared actual void manageChildDelta(Ast.ImportModule oldChild,
                                            Ast.ImportModule? newChild) {
            assert (exists oldModule);
            value builder = ModuleImportDeclarationDeltaBuilder {
                oldNode = oldChild;
                newNode = newChild;
                oldParentModule = oldModule;
                nodeComparisonListener = nodeComparisonListener;
            };
            value delta = builder.buildDelta();
            if (delta.changes.empty && delta.childrenDeltas.empty) {
                return;
            }
            childrenDeltas.add(delta);
        }

        registerMemberAddedChange(Ast.ImportModule newChild)
                => changes.add(ModuleImportAdded(
                    importedModuleName(newChild),
                    newChild.version.text.trim('"'.equals),
                    hasAnnotation(newChild.annotationList, "shared", newChild.unit)
                    then visibleOutside else invisibleOutside
                ));

        shared actual void registerRemovedChange() {
            assert (false);  // TODO: this will change when we fully support module descriptor incremental build
        }

        shared actual void calculateLocalChanges() {
            assert (exists newNode);
            if (any {
                oldNode.version.text != newNode.version.text,
                formatPath(oldNode.importPath.identifiers)
                != formatPath(newNode.importPath.identifiers),
                !sameBackend(
                    oldNode.annotationList, oldNode.unit,
                    newNode.annotationList, newNode.unit)
            }) {
                changes.add(structuralChange);
                return;
            }
        }

        getChildren(Ast.ModuleDescriptor astNode)
                => [ if (! structuralChange in changes)
                     for (im in astNode.importModuleList.importModules)
                     im ];
    }

    class ModuleImportDeclarationDeltaBuilder(Ast.ImportModule oldNode,
                                              Ast.ImportModule? newNode,
                                              Module oldParentModule,
                                              NodeComparisonListener? nodeComparisonListener)
            extends DeltaBuilder<Ast.ImportModule, Nothing>(oldNode, newNode) {

        variable ModuleImportDelta.PossibleChange? change = null;

        shared actual ModuleImportDelta buildDelta() {
            recurse();
            return object satisfies ModuleImportDelta {
                shared actual ModuleImport changedElement {
                    value moduleImport = { *oldParentModule.imports }.find {
                        Boolean selecting(ModuleImport element) {
                            value modelName = element.\imodule?.nameAsString else unknownKey();
                            value modelVersion = element.\imodule?.version else unknownKey();
                            value astName = importedModuleName(oldNode);
                            value astVersion = oldNode.version.text.trim('"'.equals);

                            return modelName == astName
                                && modelVersion == astVersion;
                        }
                    };
                    assert (exists moduleImport);
                    return moduleImport;
                }
                changes => if (exists existingChange = change) then [existingChange] else [];
                equals(Object that) => (super of AbstractDelta).equals(that);
                changedElementString => "ModuleImport[``changedElement.\imodule.nameAsString``, ``changedElement.\imodule.version``]";
            };
        }

        shared actual void calculateLocalChanges() {
            assert (exists newNode);

            function isOptional(Ast.ImportModule descriptor)
                    => hasAnnotation(descriptor.annotationList, "optional", descriptor.unit);

            if (any{
                isOptional(oldNode) != isOptional(newNode),
                !sameBackend(
                    oldNode.annotationList, oldNode.unit,
                    newNode.annotationList, newNode.unit)
            }) {
                change = structuralChange;
                return;
            }

            function isShared(Ast.ImportModule descriptor)
                    => hasAnnotation(descriptor.annotationList, "shared", descriptor.unit);

            value sharedBefore = isShared(oldNode);
            value sharedNow = isShared(newNode);

            if (sharedBefore && !sharedNow) {
                change = madeInvisibleOutsideScope;
            }
            if (!sharedBefore && sharedNow) {
                change = madeVisibleOutsideScope;
            }
        }

        manageChildDelta(Nothing oldChild, Nothing? newChild) => noop();
        registerMemberAddedChange(Nothing newChild) => noop();
        
        shared actual void registerRemovedChange() {
            change = removed;
        }

        getChildren(Ast.ImportModule astNode) => [];
    }

    class RegularCompilationUnitDeltaBuilder(Ast.CompilationUnit oldNode,
                                             Ast.CompilationUnit newNode,
                                             NodeComparisonListener? nodeComparisonListener)
            extends DeltaBuilder<Ast.CompilationUnit, Ast.Declaration>(oldNode, newNode) {

        variable value changes = ArrayList<RegularCompilationUnitDelta.PossibleChange>();
        variable value childrenDeltas = ArrayList<TopLevelDeclarationDelta>();

        shared actual RegularCompilationUnitDelta buildDelta() {
            recurse();
            return object satisfies RegularCompilationUnitDelta {
                changedElement => oldNode.unit;
                changes => outer.changes;
                childrenDeltas => outer.childrenDeltas;
                equals(Object that) => (super of AbstractDelta).equals(that);
            };
        }

        shared actual void manageChildDelta(Ast.Declaration oldChild,
                                            Ast.Declaration? newChild) {
            assert (oldChild.declarationModel.toplevel);
            value builder = TopLevelDeclarationDeltaBuilder {
                oldNode = oldChild;
                newNode = newChild;
                nodeComparisonListener = nodeComparisonListener;
            };
            value delta = builder.buildDelta();
            if (!delta.changes.empty || !delta.childrenDeltas.empty) {
                childrenDeltas.add(delta);
            }
        }

        shared actual void registerMemberAddedChange(Ast.Declaration newChild) {
            assert (newChild.declarationModel.toplevel);
            changes.add(TopLevelDeclarationAdded {
                name = newChild.declarationModel.nameAsString;
                visibility = newChild.declarationModel.shared then visibleOutside else invisibleOutside;
            });
        }

        shared actual void registerRemovedChange() {
            "A compilation unit cannot be removed from a PhasedUnit"
            assert (false);
        }

        shared actual void calculateLocalChanges() {
            // No structural change can occur within a compilation unit
            // Well ... is it true ? What about the initialization order of toplevel declarations ?
            // TODO consider the declaration order of top-levels inside a compilation unit as a structural change ?
            // TODO extend this question to the order of declaration inside the initialization section :
            //      we should check that the initialization section of a class is not changed
            // TODO more generally : where is the order of declaration important ? and when an order change can trigger compilation errors ?

        }

        shared actual Ast.Declaration[] getChildren(Ast.CompilationUnit astNode) {
            value children = ArrayList<Ast.Declaration>(5);
            object visitor extends Visitor() {
                shared actual void visitAny(AstAbstractNode? node) {
                    if (is Ast.Declaration declaration = node) {
                        assert (declaration.declarationModel.toplevel);
                        children.add(declaration);
                    } else {
                        super.visitAny(node);
                    }
                }
            }
            astNode.visitChildren(visitor);
            return children.sequence();
        }
    }

    interface MemberDeltaBuider satisfies AbstractDeltaBuilder {
        shared actual formal NestedDeclarationDelta | SpecifierDelta buildDelta();
    }
    
    class SpecifierDeltaBuilder(Ast.SpecifierStatement oldNode,
                                Ast.SpecifierStatement? newNode,
                                NodeComparisonListener? nodeComparisonListener)
            extends DeltaBuilder<Ast.SpecifierStatement, Nothing>(oldNode, newNode)
            satisfies MemberDeltaBuider {
        
        variable value changes = ArrayList<SpecifierDelta.PossibleChange>();
        
        shared actual SpecifierDelta buildDelta() {
            recurse();
            return object satisfies SpecifierDelta {
                changedElement => oldNode.declaration;
                changes => outer.changes;
                equals(Object that) => (super of AbstractDelta).equals(that);
            };
        }
        
        manageChildDelta(Nothing oldChild, Nothing? newChild) => noop();
        
        registerMemberAddedChange(Nothing newChild) => noop();
        
        registerRemovedChange() => noop();
        
        
        shared actual void calculateLocalChanges() {
            // No structural change can occur within a compilation unit
            // Well ... is it true ? What about the initialization order of toplevel declarations ?
            // TODO consider the declaration order of top-levels inside a compilation unit as a structural change ?
            // TODO extend this question to the order of declaration inside the initialization section :
            //      we should check that the initialization section of a class is not changed
            // TODO more generally : where is the order of declaration important ? and when an order change can trigger compilation errors ?
            
        }
        
        getChildren(Ast.SpecifierStatement astNode) => [];
    }

    abstract class DeclarationDeltaBuilder(Ast.Declaration oldNode,
                                           Ast.Declaration? newNode,
                                           NodeComparisonListener? nodeComparisonListener)
            of TopLevelDeclarationDeltaBuilder | NestedDeclarationDeltaBuilder
            extends DeltaBuilder<Ast.Declaration, Ast.Statement>(oldNode, newNode) {

        value specialAnnotations = ["shared", "license", "by", "see", "doc"];

        shared variable MutableList<NestedDeclarationDelta|SpecifierDelta> childrenDeltas
                = ArrayList<NestedDeclarationDelta|SpecifierDelta>();
        shared formal void addChange(NestedDeclarationDelta.PossibleChange|TopLevelDeclarationDelta.PossibleChange change);
        
        shared formal {ImpactingChange*} changes;

        shared actual void manageChildDelta(Ast.Statement oldChild,
                                            Ast.Statement? newChild) {
            NestedDeclarationDeltaBuilder | SpecifierDeltaBuilder builder;
            switch(oldChild)
            case (is Ast.Declaration) {
                assert (! oldChild.declarationModel.toplevel,
                        is Ast.Declaration? newChild);
                builder = NestedDeclarationDeltaBuilder {
                    oldNode = oldChild;
                    newNode = newChild;
                    nodeComparisonListener = nodeComparisonListener;
                };
            }
            case (is Ast.SpecifierStatement) {
                assert (is Ast.SpecifierStatement? newChild);
                builder = SpecifierDeltaBuilder {
                    oldNode = oldChild;
                    newNode = newChild;
                    nodeComparisonListener = nodeComparisonListener;
                };
            }
            else {
                return;
            }
            
            value delta = builder.buildDelta();
            if (delta.changes.empty && delta.childrenDeltas.empty) {
                return;
            }
            childrenDeltas.add(delta);
        }

        shared actual Ast.Statement[] getChildren(Ast.Declaration astNode) {
            ArrayList<Ast.Statement> children = ArrayList<Ast.Statement>(5);
            object visitor extends Visitor() {
                shared actual void visitAny(AstAbstractNode node) {
                    if (is Ast.Declaration declaration = node) {
                        assert (!declaration.declarationModel.toplevel);
                        if (declaration.declarationModel.shared) {
                            children.add(declaration);
                        }
                    } else if (is Ast.SpecifierStatement specifier = node,
                                specifier.refinement) {
                        children.add(specifier);
                    } else {
                        super.visitAny(node);
                    }
                }
            }
            astNode.visitChildren(visitor);
            return children.sequence();
        }

        registerMemberAddedChange(Ast.Statement newChild)
                => addChange(DeclarationMemberAdded {
                    name = switch(newChild)
                    case (is Ast.Declaration) newChild.declarationModel.nameAsString
                    case (is Ast.SpecifierStatement) newChild.declaration.nameAsString
                    else "<unknown>";
                });
        
        registerRemovedChange() => addChange(removed);

        shared Boolean hasStructuralChanges(Ast.Declaration oldAstDeclaration,
                                            Ast.Declaration newAstDeclaration,
                                            NodeComparisonListener? listener) {

            ModelDeclaration? identifierToDeclaration(Ast.Identifier? id)
                    => id?.unit?.getImport(TreeUtil.name(id))?.declaration;

            object nodeSigner extends VisitorAdaptor() {
                variable value builder = StringBuilder();
                variable Boolean mustSearchForIndentifierDeclaration = false;

                shared String sign(AstAbstractNode node) {
                    builder = StringBuilder();
                    mustSearchForIndentifierDeclaration = false;
                    node.visit(this);
                    return builder.string;
                }

                void enclose(String title, void action()) {
                    builder.append("``title``[");
                    action();
                    builder.append("]");
                }

                shared actual void visitType(Ast.Type node) {
                    enclose {
                        title => node is Ast.StaticType then "Type" else node.nodeType;
                        void action() {
                            if (exists type = node.typeModel) {
                                builder.append(producedTypeNamePrinter.print(type, node.unit));
                            }
                        }
                    };
                }

                shared actual void visitAny(AstAbstractNode node) {
                    Visitor v = this;
                    enclose {
                        title => node.nodeType;
                        void action() {
                            node.visitChildren(v);
                        }
                    };
                }

                shared actual void visitStaticMemberOrTypeExpression(Ast.StaticMemberOrTypeExpression node) {
                    mustSearchForIndentifierDeclaration = true;
                    super.visitStaticMemberOrTypeExpression(node);
                    mustSearchForIndentifierDeclaration = false;
                }

                shared actual void visitIdentifier(Ast.Identifier node) {
                    if (is Function method = node.scope?.scope,
                        method.parameter,
                        method.nameAsString != node.text) {
                        // parameters of a method functional parameter are not
                        // part of the externally visible structure of the outer method
                        return;
                    }
                    enclose {
                        title = node.nodeType;
                        void action() {
                            variable value identifier = node.text else null;
                            if (mustSearchForIndentifierDeclaration) {
                                mustSearchForIndentifierDeclaration = false;
                                if (exists decl = identifierToDeclaration(node)) {
                                    identifier = decl.qualifiedNameString;
                                } else {
                                    if (exists decl = node.unit?.\ipackage?.getMemberOrParameter(node.unit, identifier, null, false)) {
                                        identifier = decl.qualifiedNameString;
                                    }
                                }
                            }
                            builder.append(identifier else "<null>");
                        }
                    };
                }
            }

            String annotationName(Ast.Annotation annot) {
                assert (is Ast.BaseMemberExpression primary = annot.primary);
                value identifier = primary.identifier else null;
                value declaration = identifierToDeclaration(identifier);
                return if (exists declaration)
                    then declaration.name
                    else TreeUtil.name(identifier);         }

            Set<String> annotationsAsStringSet(Ast.AnnotationList annotationList)
                    => TreeSet {
                        compare(String x, String y) => x<=>y;
                        for (annotation in annotationList.annotations)
                        if (!annotationName(annotation) in specialAnnotations)
                        nodeSigner.sign(annotation)
                    };

            Boolean nodesDiffer(AstAbstractNode? oldNode,
                                AstAbstractNode? newNode,
                                String declarationMemberName) {
                Boolean changed;
                if (exists oldNode, exists newNode) {
                    value oldSignature = nodeSigner.sign(oldNode);
                    value newSignature = nodeSigner.sign(newNode);
                    listener?.comparedNodes {
                        oldNode = oldSignature;
                        newNode = newSignature;
                        declaration = oldAstDeclaration;
                        attribute = declarationMemberName;
                    };
                    changed = oldSignature != newSignature
                            || !errorListsEquals(oldNode.errors, newNode.errors);
                } else {
                    changed = oldNode exists || newNode exists;
                    if (exists listener) {
                        value oldSignature
                                = if (exists oldNode)
                                then nodeSigner.sign(oldNode)
                                else null;
                        value newSignature
                                = if (exists newNode)
                                then nodeSigner.sign(newNode)
                                else null;
                        listener.comparedNodes {
                            oldNode = oldSignature;
                            newNode = newSignature;
                            declaration = oldAstDeclaration;
                            attribute = declarationMemberName;
                        };
                    }
                }
                return changed;
            }

            function lookForChanges<NodeType>(ClassOrInterface<NodeType> checkedType,
                        Boolean between(NodeType oldNode, NodeType newNode))
                    given NodeType satisfies Ast.Declaration {
                if (is NodeType oldAstDeclaration) {
                    if (is NodeType newAstDeclaration) {
                        return between(oldAstDeclaration, newAstDeclaration);
                    } else {
                        // There are changes since the declaration type is not the same
                        return true;
                    }
                }
                // Don't search For Changes
                return false;
            }

            Boolean hasChanges = lookForChanges {
                checkedType = `Ast.Declaration`;
                function between(Ast.Declaration oldNode,
                                 Ast.Declaration newNode) {
                    assert (exists oldDeclaration = oldNode.declarationModel);
                    assert (exists newDeclaration = newNode.declarationModel);
                    value oldAnnotations = annotationsAsStringSet(oldNode.annotationList);
                    value newAnnotations = annotationsAsStringSet(newNode.annotationList);
                    listener?.comparedNodes {
                        oldNode = oldAnnotations.string;
                        newNode = newAnnotations.string;
                        declaration = oldNode;
                        attribute = "annotationList";
                    };
                    return any {
                        oldAnnotations != newAnnotations,
                        !errorListsEquals(oldNode.errors, newNode.errors),
                        lookForChanges {
                            checkedType=`Ast.Constructor`;
                            between(Ast.Constructor oldConstructor,
                                    Ast.Constructor newConstructor)
                                => any {
                                    nodesDiffer(oldConstructor.delegatedConstructor, newConstructor.delegatedConstructor, "delegatedConstructor"),
                                    nodesDiffer(oldConstructor.parameterList, newConstructor.parameterList, "parameterList")
                                };
                        },
                        lookForChanges {
                            checkedType=`Ast.Enumerated`;
                            between(Ast.Enumerated oldEnumerated,
                                    Ast.Enumerated newEnumerated)
                                => nodesDiffer(oldEnumerated.delegatedConstructor, newEnumerated.delegatedConstructor, "delegatedConstructor");
                        },
                        lookForChanges {
                            checkedType=`Ast.TypedDeclaration`;
                            between(Ast.TypedDeclaration oldTyped,
                                    Ast.TypedDeclaration newTyped)
                                => any {
                                    nodesDiffer(oldTyped.type, newTyped.type, "type"),
                                    lookForChanges {
                                        checkedType=`Ast.AnyMethod`;
                                        between(Ast.AnyMethod oldMethod,
                                                Ast.AnyMethod newMethod)
                                            => any {
                                                nodesDiffer(oldMethod.typeConstraintList, newMethod.typeConstraintList, "typeConstraintList"),
                                                nodesDiffer(oldMethod.typeParameterList, newMethod.typeParameterList, "typeParameterList"),
                                                oldMethod.parameterLists.size() != newMethod.parameterLists.size(),
                                                anyPair({ *oldMethod.parameterLists }, { *newMethod.parameterLists })
                                                ((oldParamList, newParamlist)
                                                            => nodesDiffer(oldParamList, newParamlist, "parameterLists"))
                                            };
                                    },
                                    lookForChanges {
                                        checkedType=`Ast.ObjectDefinition`;
                                        between(Ast.ObjectDefinition oldObject,
                                                Ast.ObjectDefinition newObject)
                                            => any {
                                                nodesDiffer(oldObject.extendedType, newObject.extendedType, "extendedType"),
                                                nodesDiffer(oldObject.satisfiedTypes, newObject.satisfiedTypes, "satisfiedTypes")
                                            };
                                    },
                                    lookForChanges {
                                        checkedType=`Ast.Variable`;
                                        between(Ast.Variable oldVariable,
                                                Ast.Variable newVariable)
                                            => any {
                                                oldVariable.parameterLists.size() != oldVariable.parameterLists.size(),
                                                anyPair({ *oldVariable.parameterLists }, { *newVariable.parameterLists })
                                                ((oldParamList, newParamlist)
                                                            => nodesDiffer(oldParamList, newParamlist, "parameterLists"))
                                            };
                                    }
                                };
                        },
                        lookForChanges {
                            checkedType=`Ast.TypeDeclaration`;
                            function between(Ast.TypeDeclaration oldType,
                                             Ast.TypeDeclaration newType)
                                => any {
                                    nodesDiffer(oldType.typeParameterList, newType.typeParameterList, "typeParameterList"),
                                    lookForChanges {
                                        checkedType=`Ast.ClassOrInterface`;
                                        between(Ast.ClassOrInterface oldClassOrInterface,
                                                Ast.ClassOrInterface newClassOrInterface)
                                            => any {
                                                lookForChanges {
                                                    checkedType=`Ast.AnyClass`;
                                                    between(Ast.AnyClass oldClass,
                                                            Ast.AnyClass newClass)
                                                        => any {
                                                            nodesDiffer(oldClass.typeConstraintList, newClass.typeConstraintList, "typeConstraintList"),
                                                            nodesDiffer(oldClass.extendedType, newClass.extendedType, "extendedType"),
                                                            nodesDiffer(oldClass.caseTypes, newClass.caseTypes, "caseTypes"),
                                                            nodesDiffer(oldClass.satisfiedTypes, newClass.satisfiedTypes, "satisfiedTypes"),
                                                            nodesDiffer(oldClass.parameterList, newClass.parameterList, "parameterList"),
                                                            lookForChanges {
                                                                checkedType=`Ast.ClassDeclaration`;
                                                                between(Ast.ClassDeclaration oldClassDecl,
                                                                        Ast.ClassDeclaration newClassDecl)
                                                                    => nodesDiffer(oldClassDecl.classSpecifier, newClassDecl.classSpecifier, "classSpecifier");
                                                            }
                                                        };
                                                },
                                                lookForChanges {
                                                    checkedType=`Ast.AnyInterface`;
                                                    between(Ast.AnyInterface oldInterface,
                                                            Ast.AnyInterface newInterface)
                                                        => any {
                                                            nodesDiffer(oldInterface.typeConstraintList, newInterface.typeConstraintList, "typeConstraintList"),
                                                            nodesDiffer(oldInterface.caseTypes, newInterface.caseTypes, "caseTypes"),
                                                            nodesDiffer(oldInterface.satisfiedTypes, newInterface.satisfiedTypes, "satisfiedTypes"),
                                                            lookForChanges {
                                                                checkedType=`Ast.InterfaceDeclaration`;
                                                                between(Ast.InterfaceDeclaration oldInterfaceDecl,
                                                                        Ast.InterfaceDeclaration newInterfaceDecl)
                                                                    => nodesDiffer(oldInterfaceDecl.typeSpecifier, newInterfaceDecl.typeSpecifier, "typeSpecifier");
                                                            },
                                                            lookForChanges {
                                                                checkedType=`Ast.InterfaceDefinition`;
                                                                function between(Ast.InterfaceDefinition oldInterface,
                                                                                 Ast.InterfaceDefinition newInterface) {
                                                                    listener?.comparedNodes {
                                                                        oldNode = oldInterface.\idynamic.string;
                                                                        newNode = newInterface.\idynamic.string;
                                                                        declaration = oldNode;
                                                                        attribute = "dynamic";
                                                                    };
                                                                    return oldInterface.\idynamic != newInterface.\idynamic;
                                                                }
                                                            }
                                                        };
                                                }
                                            };
                                    },
                                    lookForChanges {
                                        checkedType=`Ast.TypeAliasDeclaration`;
                                        between(Ast.TypeAliasDeclaration oldTypeAliasDeclaration,
                                                Ast.TypeAliasDeclaration newTypeAliasDeclaration)
                                            => any {
                                                nodesDiffer(oldTypeAliasDeclaration.typeConstraintList, newTypeAliasDeclaration.typeConstraintList, "typeConstraintList"),
                                                nodesDiffer(oldTypeAliasDeclaration.typeSpecifier, newTypeAliasDeclaration.typeSpecifier, "typeSpecifier")
                                            };
                                    },
                                    lookForChanges {
                                        checkedType=`Ast.TypeConstraint`;
                                        between(Ast.TypeConstraint oldTypeConstraint,
                                                Ast.TypeConstraint newTypeConstraint)
                                            => any {
                                                nodesDiffer(oldTypeConstraint.caseTypes, newTypeConstraint.caseTypes, "caseTypes"),
                                                nodesDiffer(oldTypeConstraint.satisfiedTypes, newTypeConstraint.satisfiedTypes, "satisfiedTypes"),
                                                nodesDiffer(oldTypeConstraint.abstractedType, newTypeConstraint.abstractedType, "abstractedType")
                                            };
                                    }
                                };
                        },
                        lookForChanges {
                            checkedType=`Ast.TypeParameterDeclaration`;
                            between(Ast.TypeParameterDeclaration oldTypeParameter,
                                    Ast.TypeParameterDeclaration newTypeParameter)
                                => any {
                                    nodesDiffer(oldTypeParameter.typeSpecifier, newTypeParameter.typeSpecifier, "typeSpecifier"),
                                    nodesDiffer(oldTypeParameter.typeVariance, newTypeParameter.typeVariance, "typeVariance")
                                };
                        }
                    };
                }
            };

            listener?.comparedDeclaration(oldAstDeclaration, hasChanges);
            return hasChanges;
        }
    }

    class TopLevelDeclarationDeltaBuilder(Ast.Declaration oldNode,
                                          Ast.Declaration? newNode,
                                          NodeComparisonListener? nodeComparisonListener)
            extends DeclarationDeltaBuilder(oldNode, newNode, nodeComparisonListener) {

        variable value _changes = ArrayList<TopLevelDeclarationDelta.PossibleChange>();
        shared actual {TopLevelDeclarationDelta.PossibleChange*} changes => _changes;
        
        shared actual void addChange(change) {
            NestedDeclarationDelta.PossibleChange|TopLevelDeclarationDelta.PossibleChange change;
            _changes.add(change);
        }
        
        shared actual TopLevelDeclarationDelta buildDelta() {
            recurse();
            return object satisfies TopLevelDeclarationDelta {
                changedElement => oldNode.declarationModel;
                changes => outer._changes;
                childrenDeltas => outer.childrenDeltas;
                equals(Object that) => (super of AbstractDelta).equals(that);
            };
        }

        shared actual void calculateLocalChanges() {
            assert (exists newNode);

            assert (exists oldDeclaration = oldNode.declarationModel);
            assert (exists newDeclaration = newNode.declarationModel);
            if (oldDeclaration.shared && !newDeclaration.shared) {
                _changes.add(madeInvisibleOutsideScope);
            }
            if (!oldDeclaration.shared && newDeclaration.shared) {
                _changes.add(madeVisibleOutsideScope);
            }

            if (hasStructuralChanges(oldNode, newNode, nodeComparisonListener)) {
                _changes.add(structuralChange);
            }
        }
    }


    class NestedDeclarationDeltaBuilder(Ast.Declaration oldNode,
                                        Ast.Declaration? newNode,
                                        NodeComparisonListener? nodeComparisonListener)
            extends DeclarationDeltaBuilder(oldNode, newNode, nodeComparisonListener)
            satisfies MemberDeltaBuider {

        variable value _changes = ArrayList<NestedDeclarationDelta.PossibleChange>();
        shared actual {NestedDeclarationDelta.PossibleChange*} changes => _changes;
        
        shared actual void addChange(change) {
            NestedDeclarationDelta.PossibleChange|TopLevelDeclarationDelta.PossibleChange change;
            assert (is NestedDeclarationDelta.PossibleChange change);
            _changes.add(change);
        }
        
        shared actual NestedDeclarationDelta buildDelta() {
            recurse();
            return object satisfies NestedDeclarationDelta {
                changedElement => oldNode.declarationModel;
                changes => outer._changes;
                childrenDeltas => outer.childrenDeltas;
                equals(Object that) => (super of AbstractDelta).equals(that);

            };
        }

        shared actual void calculateLocalChanges() {
            assert (exists newNode);
            if (hasStructuralChanges(oldNode, newNode, nodeComparisonListener)) {
                _changes.add(structuralChange);
            }
        }
    }
}


