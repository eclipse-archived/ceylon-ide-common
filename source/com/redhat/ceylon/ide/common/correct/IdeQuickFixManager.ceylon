import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject
}

import java.util {
    ArrayList,
    Collection
}

shared interface QuickFixData<Project> {
    shared formal Integer errorCode;
    shared formal Integer problemOffset;
    shared formal Integer problemLength;
    shared formal Node node;
    shared formal Tree.CompilationUnit rootNode;
    shared formal Project project;
    shared formal BaseCeylonProject ceylonProject;
}

shared abstract class IdeQuickFixManager<IDocument,InsertEdit,TextEdit,TextChange,Region,Project,IFile,ICompletionProposal,Data,LinkedMode>()
        given Data satisfies QuickFixData<Project> {
    
    shared formal AddAnnotationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addAnnotations;
    shared formal RemoveAnnotationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> removeAnnotations;
    shared formal ImportProposals<IFile,ICompletionProposal,IDocument,InsertEdit,TextEdit,TextChange> importProposals;
    shared formal CreateQuickFix<IFile,Project,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,ICompletionProposal> createQuickFix;
    shared CreateParameterQuickFix<IFile,Project,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,ICompletionProposal> createParameterQuickFix
            => createQuickFix.createParameterQuickFix;
    shared formal ChangeReferenceQuickFix<IFile,Project,IDocument,InsertEdit,TextEdit,TextChange,Data,Region,ICompletionProposal> changeReferenceQuickFix;
    shared formal DeclareLocalQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,LinkedMode,ICompletionProposal,Project,Data,Region> declareLocalQuickFix;
    shared formal CreateEnumQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> createEnumQuickFix;
    shared formal RefineFormalMembersQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> refineFormalMembersQuickFix;
    shared formal SpecifyTypeQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal,LinkedMode> specifyTypeQuickFix;
    shared formal ExportModuleImportQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> exportModuleImportQuickFix;
    shared formal AddPunctuationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addPunctuationQuickFix;
    shared formal AddParameterListQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addParameterListQuickFix;
    shared formal AddParameterQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addParameterQuickFix;
    shared formal AddInitializerQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addInitializerQuickFix;
    shared formal AddConstructorQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addConstructorQuickFix;
    shared formal ChangeDeclarationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> changeDeclarationQuickFix;
    shared formal FixAliasQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> fixAliasQuickFix;
    shared formal AppendMemberReferenceQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> appendMemberReferenceQuickFix;
    shared formal ChangeTypeQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> changeTypeQuickFix;
    shared formal AddSatisfiesQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addSatisfiesQuickFix;
    shared formal AddSpreadToVariadicParameterQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addSpreadToVariadicParameterQuickFix;
    shared formal AddTypeParameterQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addTypeParameterQuickFix;
    shared formal ShadowReferenceQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> shadowReferenceQuickFix; 
    shared formal ChangeInitialCaseQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> changeInitialCaseQuickFix;
    shared formal FixMultilineStringIndentationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> fixMultilineStringIndentationQuickFix;
    shared formal AddModuleImportQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addModuleImportQuickFix;
    shared formal RenameDescriptorQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> renameDescriptorQuickFix;
    shared formal ChangeRefiningTypeQuickType<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> changeRefiningTypeQuickType;
    shared formal SwitchQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> switchQuickFix;
    shared formal ChangeToQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> changeToQuickFix;
    shared formal AddNamedArgumentQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addNamedArgumentQuickFix;
    
    shared formal void addImportProposals(Collection<ICompletionProposal> proposals, Data quickFixData);
    
    // temporary
    shared formal void addCreateTypeParameterProposal<Data>(Data data,
        Tree.BaseType bt, String brokenName)
            given Data satisfies QuickFixData<Project>;

    shared void addQuickFixes(Data data, TypeChecker? tc, IFile file) {
        
        value node = data.node;
        value project = data.project;
        
        switch (data.errorCode)
        case (100|102) {
            if (data.errorCode == 100) {
                declareLocalQuickFix.addDeclareLocalProposal(data, file);
            }

            if (exists tc) {
                value proposals = ArrayList<ICompletionProposal>();
                importProposals.addImportProposals(data.rootNode, data.node, proposals, file);
                addImportProposals(proposals, data);
            }
            createEnumQuickFix.addCreateEnumProposal(project, data);
            addCreationProposals(data, file);
            if (exists tc) {
                changeReferenceQuickFix.addChangeReferenceProposals(data, file);
            }
        }
        case (101) {
            createParameterQuickFix.addCreateParameterProposals(data);
            if (exists tc) {
                changeReferenceQuickFix.addChangeArgumentReferenceProposals(data, file);
            }
        }
        case (200) {
            assert(is Tree.Type node);
            specifyTypeQuickFix.addSpecifyTypeProposal(node, data);
        }
        case (300) {
            refineFormalMembersQuickFix.addRefineFormalMembersProposal(data, false);
            addAnnotations.addMakeAbstractDecProposal(node, project, data);
        }
        case (350) {
            refineFormalMembersQuickFix.addRefineFormalMembersProposal(data, true);
            addAnnotations.addMakeAbstractDecProposal(node, project, data);
        }
        case (310) {
            addAnnotations.addMakeAbstractDecProposal(node, project, data);
        }
        case (320) {
            removeAnnotations.addRemoveAnnotationProposal(node, "formal", project, data);
        }
        case (400|402) {
            addAnnotations.addMakeSharedProposal(project, node, data);
        }
        case (705) {
            addAnnotations.addMakeSharedDecProposal(project, node, data);
        }
        case (500|510) {
            addAnnotations.addMakeDefaultProposal(project, node, data);
        }
        case (600) {
            addAnnotations.addMakeActualDecProposal(project, node, data);
        }
        case (701) {
            addAnnotations.addMakeSharedDecProposal(project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("actual", project, node, data);
        }
        case (702) {
            addAnnotations.addMakeSharedDecProposal(project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("formal", project, node, data);
        }
        case (703) {
            addAnnotations.addMakeSharedDecProposal(project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("default", project, node, data);
        }
        case (710|711) {
            addAnnotations.addMakeSharedProposal(project, node, data);
        }
        case (712) {
            exportModuleImportQuickFix.addExportModuleImportProposal(data);
        }
        case (713) {
            addAnnotations.addMakeSharedProposalForSupertypes(project, node, data);
        }
        case (714) {
            exportModuleImportQuickFix.addExportModuleImportProposalForSupertypes(data);
        }
        case (800|804) {
            addAnnotations.addMakeVariableProposal(project, node, data);
        }
        case (803) {
            addAnnotations.addMakeVariableProposal(project, node, data);
        }
        case (801) {
            addAnnotations.addMakeVariableDecProposal(project, data);
        }
        case (802) {
            // empty
        }
        case (905) {
            addAnnotations.addMakeContainerAbstractProposal(project, node, data);
        }
        case (1100) {
            addAnnotations.addMakeContainerAbstractProposal(project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("formal", project, node, data);
        }
        case (1101) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", project, node, data);
            //TODO: replace body with ;
        }
        case (1000|1001) {
            addPunctuationQuickFix.addEmptyParameterListProposal(data, file);
            addParameterListQuickFix.addParameterListProposal(data, file, false);
            addConstructorQuickFix.addConstructorProposal(data, file);
            changeDeclarationQuickFix.addChangeDeclarationProposal(data, file);
        }
        case (1020) {
            addPunctuationQuickFix.addImportWildcardProposal(data, file);
        }
        case (1050) {
            fixAliasQuickFix.addFixAliasProposal(data, file);
        }
        case (1200|1201) {
            removeAnnotations.addRemoveAnnotationDecProposal("shared", project, node, data);
        }
        case (1300|1301) {
            addAnnotations.addMakeRefinedSharedProposal(project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("actual", project, node, data);
        }
        case (1302|1312|1317) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", project, node, data);
        }
        case (1303|1313|1320) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("default", project, node, data);
        }
        case (1350) {
            removeAnnotations.addRemoveAnnotationDecProposal("default", project, node, data);
            removeAnnotations.addMakeContainerNonfinalProposal(project, node, data);
        }
        case (1400|1401) {
            addAnnotations.addMakeFormalDecProposal(project, node, data);
        }
        case (1450) {
            addAnnotations.addMakeFormalDecProposal(project, node, data);
            addParameterQuickFix.addParameterProposals(data, file);
            addInitializerQuickFix.addInitializerProposals(data, file);
            addParameterListQuickFix.addParameterListProposal(data, file, false);
            addConstructorQuickFix.addConstructorProposal(data, file);
        }
        case (1610) {
            removeAnnotations.addRemoveAnnotationDecProposal("shared", project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("abstract", project, node, data);
        }
        case (1500|1501) {
            removeAnnotations.addRemoveAnnotationDecProposal("variable", project, node, data);
        }
        case (1600|1601) {
            removeAnnotations.addRemoveAnnotationDecProposal("abstract", project, node, data);
        }
        case (1700) {
            removeAnnotations.addRemoveAnnotationDecProposal("final", project, node, data);
        }
        case (1800|1801) {
            removeAnnotations.addRemoveAnnotationDecProposal("sealed", project, node, data);
        }
        case (1900) {
            removeAnnotations.addRemoveAnnotationDecProposal("late", project, node, data);
        }
        case (1950|1951) {
            removeAnnotations.addRemoveAnnotationDecProposal("annotation", project, node, data);
        }
        case (2000) {
            createParameterQuickFix.addCreateParameterProposals(data);
        }
        case (2100) {
            appendMemberReferenceQuickFix.addAppendMemberReferenceProposals(data, file);
            changeTypeQuickFix.addChangeTypeProposals(data, file);
            addSatisfiesQuickFix.addSatisfiesProposals(data);
        }
        case (2102) {
            changeTypeQuickFix.addChangeTypeArgProposals(data, file);
            addSatisfiesQuickFix.addSatisfiesProposals(data);
        }
        case (2101) {
            addSpreadToVariadicParameterQuickFix.addSpreadToSequenceParameterProposal(data, file);
        }
        case (2500) {
            addTypeParameterQuickFix.addTypeParameterProposal(data, file);
        }
        case (3000) {
            // TODO
        }
        case (3100) {
            shadowReferenceQuickFix.addShadowReferenceProposal(data, file);
        }
        case (3101|3102) {
            shadowReferenceQuickFix.addShadowSwitchReferenceProposal(data, file);
        }
        case (5001|5002) {
            changeInitialCaseQuickFix.addChangeIdentifierCaseProposal(data, file);
        }
        case (6000) {
            fixMultilineStringIndentationQuickFix.addFixMultilineStringIndentation(data, file);
        }
        case (7000) {
            if (exists tc) {
                addModuleImportQuickFix.addModuleImportProposals(data, tc);
            }
        }
        case (8000) {
            renameDescriptorQuickFix.addRenameDescriptorProposal(data, file);
            // TODO addMoveDirProposal
        }
        case (9000) {
            changeRefiningTypeQuickType.addChangeRefiningTypeProposal(data, file);
        }
        case (9100|9200) {
            changeRefiningTypeQuickType.addChangeRefiningParametersProposal(data, file);
        }
        case (10000) {
            switchQuickFix.addElseProposal(data, file);
            switchQuickFix.addCasesProposal(data, file);
        }
        case (11000) {
            addNamedArgumentQuickFix.addNamedArgumentsProposal(data, file);
        }
        case (12000|12100) {
            changeToQuickFix.changeToVoid(data, file);
        }
        case (13000) {
            changeToQuickFix.changeToFunction(data, file);
        }
        case (20000) {
            addAnnotations.addMakeNativeProposal(project, node, file, data);
        }
        else {
        }
    }
    
    void addCreationProposals(Data data, IFile file) {
        value node = data.node;

        if (is Tree.MemberOrTypeExpression node) {
            createQuickFix.addCreateProposals(data, file);
        } else if (is Tree.SimpleType node) {
            class FindExtendedTypeExpressionVisitor() extends Visitor() {
                shared variable Tree.InvocationExpression? invocationExpression = null;
                
                shared actual void visit(Tree.ExtendedType that) {
                    super.visit(that);
                    if (that.type == node) {
                        invocationExpression = that.invocationExpression;
                    }
                }
            }
            value v = FindExtendedTypeExpressionVisitor();
            (v of Visitor).visit(data.rootNode);
            if (exists expr = v.invocationExpression) {
                createQuickFix.addCreateProposals(data, file, expr.primary);
            }
        }
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

        if (is Tree.BaseType node) {
            value bt = node;
            Tree.Identifier? id = bt.identifier;
            if (exists id) {
                value brokenName = id.text;
                addCreateTypeParameterProposal(data, bt, brokenName);
            }
        }
    }
}
