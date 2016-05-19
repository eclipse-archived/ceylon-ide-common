import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.correct {
    addAnnotations=addAnnotationQuickFix,
    removeAnnotations=removeAnnotationQuickFix
}
import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    TextChange
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type,
    Scope,
    Referenceable,
    TypeDeclaration,
    Declaration
}

import java.util {
    ArrayList,
    Collection
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}

shared interface QuickFixData {
    shared formal Integer errorCode;
    shared formal Integer problemOffset;
    shared formal Integer problemLength;
    shared formal Node node;
    shared formal Tree.CompilationUnit rootNode;
    shared formal PhasedUnit phasedUnit;
    shared formal BaseCeylonProject ceylonProject;
    shared formal CommonDocument document;
    "Set this flag to [[true]] to avoid heavy computations and delay them
     until the quick fix is called."
    shared default Boolean useLazyFixes => false;
    
    shared formal void addQuickFix(String description, TextChange|Callable<Anything, []> change,
        DefaultRegion? selection = null, 
        Boolean qualifiedNameIsPath = false,
        Icons? image = null);
    
    shared formal void addInitializerQuickFix(String description, TextChange change,
        DefaultRegion selection, Unit unit, Scope scope, Type? type);
    shared formal void addParameterQuickFix(String description, TextChange change,
        DefaultRegion selection, Unit unit, Scope scope, Type? type, Integer exitPos);
    shared formal void addParameterListQuickFix(String description, TextChange change,
        DefaultRegion selection);
    shared formal void addExportModuleImportProposal(Unit u, String description,
        String name, String version);
    shared formal void addModuleImportProposal(Unit u, String description,
        String name, String version);
    shared formal void addAnnotationProposal(Referenceable declaration, String text,
        String description, TextChange change, DefaultRegion? selection);
    shared formal void addSatisfiesProposal(TypeDeclaration typeParam,
        String description, String missingSatisfiedTypeText, TextChange change, 
        DefaultRegion? selection);
    shared formal void addChangeTypeProposal(String description, 
        TextChange change, DefaultRegion selection, Unit unit);
    shared formal void addConvertToClassProposal(String description,
        Tree.ObjectDefinition declaration);
    shared formal void addCreateParameterProposal(String description, Declaration dec,
        Type? type, DefaultRegion selection, Icons image, TextChange change, Integer exitPos);
    shared formal void addCreateQuickFix(String description,
        Scope scope, Unit unit, Type? returnType, Icons image,
        TextChange change, Integer exitPos, DefaultRegion selection);
    shared formal void addDeclareLocalProposal(String description,
        TextChange change, Tree.Term term, Tree.BaseMemberExpression bme);
    shared formal void addRefineFormalMembersProposal(String description);
    shared formal void addRefineEqualsHashProposal(String description, TextChange change);
    shared formal void addSpecifyTypeProposal(String description,
        Tree.Type type, Tree.CompilationUnit cu, Type infType);
}

shared abstract class IdeQuickFixManager<IDocument,ICompletionProposal,LinkedMode,Data>()
        given Data satisfies QuickFixData {
    
    shared formal DeclareLocalQuickFix<IDocument,LinkedMode,ICompletionProposal> declareLocalQuickFix;
    shared formal SpecifyTypeQuickFix<IDocument,ICompletionProposal,LinkedMode> specifyTypeQuickFix;
    shared formal AssignToLocalQuickFix<Data> assignToLocalQuickFix;
    
    shared formal void addImportProposals(Collection<ICompletionProposal> proposals, QuickFixData quickFixData);
    
    // temporary
    shared formal void addCreateTypeParameterProposal<Data>(Data data,
        Tree.BaseType bt, String brokenName)
            given Data satisfies QuickFixData;

    shared void addQuickFixes(Data data, TypeChecker? tc) {
        
        value node = data.node;
        
        switch (data.errorCode)
        case (100|102) {
            if (data.errorCode == 100) {
                declareLocalQuickFix.addDeclareLocalProposal(data);
            }

            if (exists tc) {
                value proposals = ArrayList<ICompletionProposal>();
                importProposals.addImportProposals(data);
                addImportProposals(proposals, data);
            }
            createEnumQuickFix.addCreateEnumProposal(data);
            addCreationProposals(data);
            if (exists tc) {
                changeReferenceQuickFix.addChangeReferenceProposals(data);
            }
        }
        case (101) {
            createParameterQuickFix.addCreateParameterProposals(data);
            if (exists tc) {
                changeReferenceQuickFix.addChangeArgumentReferenceProposals(data);
            }
        }
        case (200|210) {
            specifyTypeQuickFix.addSpecifyTypeProposal(node, data);
        }
        case (300) {
            refineFormalMembersQuickFix.addRefineFormalMembersProposal(data, false);
            addAnnotations.addMakeAbstractDecProposal(node, data);
        }
        case (350) {
            refineFormalMembersQuickFix.addRefineFormalMembersProposal(data, true);
            addAnnotations.addMakeAbstractDecProposal(node, data);
        }
        case (310) {
            addAnnotations.addMakeAbstractDecProposal(node, data);
        }
        case (320) {
            removeAnnotations.addRemoveAnnotationProposal(node, "formal", data);
        }
        case (400|402) {
            addAnnotations.addMakeSharedProposal(node, data);
        }
        case (705) {
            addAnnotations.addMakeSharedDecProposal(node, data);
        }
        case (500|510) {
            addAnnotations.addMakeDefaultProposal(node, data);
        }
        case (600) {
            addAnnotations.addMakeActualDecProposal(node, data);
        }
        case (701) {
            addAnnotations.addMakeSharedDecProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("actual", node, data);
        }
        case (702) {
            addAnnotations.addMakeSharedDecProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
        }
        case (703) {
            addAnnotations.addMakeSharedDecProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("default", node, data);
        }
        case (710|711) {
            addAnnotations.addMakeSharedProposal(node, data);
        }
        case (712) {
            exportModuleImportQuickFix.addExportModuleImportProposal(data);
        }
        case (713) {
            addAnnotations.addMakeSharedProposalForSupertypes(node, data);
        }
        case (714) {
            exportModuleImportQuickFix.addExportModuleImportProposalForSupertypes(data);
        }
        case (800|804) {
            addAnnotations.addMakeVariableProposal(node, data);
        }
        case (803) {
            addAnnotations.addMakeVariableProposal(node, data);
        }
        case (801) {
            addAnnotations.addMakeVariableDecProposal(data);
        }
        case (802) {
            // empty
        }
        case (905) {
            addAnnotations.addMakeContainerAbstractProposal(node, data);
        }
        case (1100) {
            addAnnotations.addMakeContainerAbstractProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
        }
        case (1101) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
            //TODO: replace body with ;
        }
        case (1000|1001) {
            addPunctuationQuickFix.addEmptyParameterListProposal(data);
            addParameterListQuickFix.addParameterListProposal(data, false);
            addConstructorQuickFix.addConstructorProposal(data);
            changeDeclarationQuickFix.addChangeDeclarationProposal(data);
        }
        case (1020) {
            addPunctuationQuickFix.addImportWildcardProposal(data);
        }
        case (1050) {
            fixAliasQuickFix.addFixAliasProposal(data);
        }
        case (1200|1201) {
            removeAnnotations.addRemoveAnnotationDecProposal("shared", node, data);
        }
        case (1300|1301) {
            addAnnotations.addMakeRefinedSharedProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("actual", node, data);
        }
        case (1302|1312|1317) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
        }
        case (1303|1313|1320) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("default", node, data);
        }
        case (1350) {
            removeAnnotations.addRemoveAnnotationDecProposal("default", node, data);
            removeAnnotations.addMakeContainerNonfinalProposal(node, data);
        }
        case (1400|1401) {
            addAnnotations.addMakeFormalDecProposal(node, data);
        }
        case (1450) {
            addAnnotations.addMakeFormalDecProposal(node, data);
            addParameterQuickFix.addParameterProposals(data);
            addInitializerQuickFix.addInitializerProposals(data);
            addParameterListQuickFix.addParameterListProposal(data, false);
            addConstructorQuickFix.addConstructorProposal(data);
        }
        case (1610) {
            removeAnnotations.addRemoveAnnotationDecProposal("shared", node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("abstract", node, data);
        }
        case (1500|1501) {
            removeAnnotations.addRemoveAnnotationDecProposal("variable", node, data);
        }
        case (1600|1601) {
            removeAnnotations.addRemoveAnnotationDecProposal("abstract", node, data);
        }
        case (1700) {
            removeAnnotations.addRemoveAnnotationDecProposal("final", node, data);
        }
        case (1800|1801) {
            removeAnnotations.addRemoveAnnotationDecProposal("sealed", node, data);
        }
        case (1900) {
            removeAnnotations.addRemoveAnnotationDecProposal("late", node, data);
        }
        case (1950|1951) {
            removeAnnotations.addRemoveAnnotationDecProposal("annotation", node, data);
        }
        case (2000) {
            createParameterQuickFix.addCreateParameterProposals(data);
        }
        case (2100) {
            appendMemberReferenceQuickFix.addAppendMemberReferenceProposals(data);
            changeTypeQuickFix.addChangeTypeProposals(data);
            addSatisfiesQuickFix.addSatisfiesProposals(data);
        }
        case (2102) {
            changeTypeQuickFix.addChangeTypeArgProposals(data);
            addSatisfiesQuickFix.addSatisfiesProposals(data);
        }
        case (2101) {
            addSpreadToVariadicParameterQuickFix.addSpreadToSequenceParameterProposal(data);
        }
        case (2500) {
            addTypeParameterQuickFix.addTypeParameterProposal(data);
        }
        case (3000) {
            assignToLocalQuickFix.addProposal(data);
            // TODO
        }
        case (3100) {
            shadowReferenceQuickFix.addShadowReferenceProposal(data);
        }
        case (3101|3102) {
            shadowReferenceQuickFix.addShadowSwitchReferenceProposal(data);
        }
        case (5001|5002) {
            changeInitialCaseQuickFix.addChangeIdentifierCaseProposal(data);
        }
        case (6000) {
            fixMultilineStringIndentationQuickFix.addFixMultilineStringIndentation(data);
        }
        case (7000) {
            if (exists tc) {
                addModuleImportQuickFix.addModuleImportProposals(data, tc);
            }
        }
        case (8000) {
            renameDescriptorQuickFix.addRenameDescriptorProposal(data);
            // TODO addMoveDirProposal
        }
        case (9000) {
            changeRefiningTypeQuickType.addChangeRefiningTypeProposal(data);
        }
        case (9100|9200) {
            changeRefiningTypeQuickType.addChangeRefiningParametersProposal(data);
        }
        case (10000) {
            switchQuickFix.addElseProposal(data);
            switchQuickFix.addCasesProposal(data);
        }
        case (11000) {
            addNamedArgumentQuickFix.addNamedArgumentsProposal(data);
        }
        case (12000|12100) {
            changeToQuickFix.changeToVoid(data);
        }
        case (13000) {
            changeToQuickFix.changeToFunction(data);
        }
        case (20000) {
            addAnnotations.addMakeNativeProposal(node, data);
        }
        case (20010) {
            addAnnotations.addMakeContainerNativeProposal(node, data);
        }
        else {
        }
    }
    
    void addCreationProposals(QuickFixData data) {
        value node = data.node;
        
        switch (node)
        case (is Tree.MemberOrTypeExpression) {
            createQuickFix.addCreateProposals(data);
        }
        case (is Tree.SimpleType) {
            object extends Visitor() {
                shared actual void visit(Tree.ExtendedType that) {
                    super.visit(that);
                    if (that.type == node) {
                        createQuickFix.addCreateProposals(data, 
                            that.invocationExpression.primary);
                    }
                }
            }.visit(data.rootNode);
        }
        else {}
        
        //TODO: should we add this stuff back in??
        /*else if (node instanceof Tree.BaseType) {
            Tree.BaseType bt = (Tree.BaseType) node;
            String brokenName = bt.getIdentifier().getText();
            String idef = "interface " + brokenName + " {}";
            String idesc = "interface '" + brokenName + "'";
            String cdef = "class " + brokenName + "() {}";
            String cdesc = "class '" + brokenName + "()'";
            //addCreateLocalProposals(proposals, project, idef, idesc, INTERFACE, cu, bt);
            addCreateLocalProposals(proposals, project, cdef, cdesc, CLASS, cu, bt, null, null);
            addCreateToplevelProposals(proposals, project, idef, idesc, INTERFACE, cu, bt, null, null);
            addCreateToplevelProposals(proposals, project, cdef, cdesc, CLASS, cu, bt, null, null);
            CreateInNewUnitProposal.addCreateToplevelProposal(proposals, idef, idesc, 
                    INTERFACE, file, brokenName, null, null);
            CreateInNewUnitProposal.addCreateToplevelProposal(proposals, cdef, cdesc, 
                    CLASS, file, brokenName, null, null);
            
         }*/

        if (is Tree.BaseType node, 
            exists id = node.identifier) {
            addCreateTypeParameterProposal(data, node, id.text);
        }
    }
}
