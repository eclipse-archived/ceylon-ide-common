import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree,
    Visitor
}
import java.util {
    ArrayList,
    Collection
}

shared interface QuickFixData<Project> {
    shared formal Integer errorCode;
    shared formal Integer problemOffset;
    shared formal Node node;
    shared formal Tree.CompilationUnit rootNode;
    shared formal Project project;
}

shared abstract class IdeQuickFixManager<IDocument,InsertEdit,TextEdit,TextChange,Region,Project,IFile,ICompletionProposal,Data,LinkedMode>()
        given Data satisfies QuickFixData<Project> {
    
    shared formal AddAnnotationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> addAnnotations;
    shared formal RemoveAnnotationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,ICompletionProposal> removeAnnotations;
    shared formal ImportProposals<IFile,ICompletionProposal,IDocument,InsertEdit,TextEdit,TextChange> importProposals;
    shared formal CreateQuickFix<IFile, Project,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,ICompletionProposal> createQuickFix;
    shared CreateParameterQuickFix<IFile,Project,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,ICompletionProposal> createParameterQuickFix => createQuickFix.createParameterQuickFix;
    shared formal ChangeReferenceQuickFix<IFile, Project, IDocument, InsertEdit, TextEdit, TextChange, Data, Region,ICompletionProposal> changeReferenceQuickFix; 
    shared formal DeclareLocalQuickFix<IFile, IDocument, InsertEdit, TextEdit, TextChange, LinkedMode, ICompletionProposal, Project, Data, Region> declareLocalQuickFix;
    shared formal CreateEnumQuickFix<Project, IDocument, InsertEdit, TextEdit, TextChange, Data> createEnumQuickFix;
    shared formal RefineFormalMembersQuickFix<IFile, IDocument, InsertEdit, TextEdit, TextChange, Region, Project, Data, ICompletionProposal> refineFormalMembersQuickFix;
    
    shared formal void addImportProposals(Collection<ICompletionProposal> proposals, Data quickFixData);
    
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
            // TODO
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
        }
        case (400) {
            addAnnotations.addMakeSharedProposal(project, node, data);
        }
        case (705) {
            addAnnotations.addMakeSharedDecProposal(project, node, data);
        }
        case (500) {
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
        case (710) {
            addAnnotations.addMakeSharedProposal(project, node, data);
        }
        case (712) {
        }
        case (713) {
            addAnnotations.addMakeSharedProposalForSupertypes(project, node, data);
        }
        case (714) {
        }
        case (800) {
            addAnnotations.addMakeVariableProposal(project, node, data);
        }
        case (803) {
            addAnnotations.addMakeVariableProposal(project, node, data);
        }
        case (801) {
            addAnnotations.addMakeVariableDecProposal(project, data);
        }
        case (802) {
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
        }
        case (1000) {
        }
        case (1050) {
        }
        case (1200) {
            removeAnnotations.addRemoveAnnotationDecProposal("shared", project, node, data);
        }
        case (1300) {
            addAnnotations.addMakeRefinedSharedProposal(project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("actual", project, node, data);
        }
        case (1302) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", project, node, data);
        }
        case (1303) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("default", project, node, data);
        }
        case (1350) {
            removeAnnotations.addRemoveAnnotationDecProposal("default", project, node, data);
            removeAnnotations.addMakeContainerNonfinalProposal(project, node, data);
        }
        case (1400) {
            addAnnotations.addMakeFormalDecProposal(project, node, data);
        }
        case (1450) {
            addAnnotations.addMakeFormalDecProposal(project, node, data);
        }
        case (1610) {
            removeAnnotations.addRemoveAnnotationDecProposal("shared", project, node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("abstract", project, node, data);
        }
        case (1500) {
            removeAnnotations.addRemoveAnnotationDecProposal("variable", project, node, data);
        }
        case (1600) {
            removeAnnotations.addRemoveAnnotationDecProposal("abstract", project, node, data);
        }
        case (1700) {
            removeAnnotations.addRemoveAnnotationDecProposal("final", project, node, data);
        }
        case (1800) {
            removeAnnotations.addRemoveAnnotationDecProposal("sealed", project, node, data);
        }
        case (1900) {
            removeAnnotations.addRemoveAnnotationDecProposal("late", project, node, data);
        }
        case (1950) {
            removeAnnotations.addRemoveAnnotationDecProposal("annotation", project, node, data);
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
                //TODO addCreateTypeParameterProposal(data, bt, brokenName);
            }
        }
    }
}
