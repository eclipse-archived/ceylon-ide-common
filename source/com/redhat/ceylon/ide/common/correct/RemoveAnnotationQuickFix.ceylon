import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    ModelUtil,
    ClassOrInterface
}

shared interface RemoveAnnotationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newRemoveAnnotationQuickFix(Declaration dec, String annotation,
            String desc, Integer offset, TextChange change, Region selection, Data data);
    
    shared void addRemoveAnnotationProposal(Node node, String annotation, Project project, Data data) {
        value dec = nodes.getReferencedDeclaration(node);
        if (is Declaration dec) {
            addRemoveAnnotationProposal2(node, annotation, "Make Non" + annotation, dec, project, data);
        }
    }
    
    shared void addMakeContainerNonfinalProposal(Project project, Node node, Data data) {
        Declaration dec;
        if (is Tree.Declaration node) {
            value decNode = node;
            value container = decNode.declarationModel.container;
            if (is Declaration container) {
                dec = container;
            } else {
                return;
            }
        } else {
            assert(is Declaration scope = node.scope);
            dec = scope;
        }
        addRemoveAnnotationProposal2(node, "final", "Make Nonfinal", dec, project, data);
    }
    
    void addRemoveAnnotationProposal2(Node node, String annotation, String desc,
        Declaration? dec, Project project, Data data) {
        
        if (exists dec, exists d = dec.name,
            exists phasedUnit = getPhasedUnit(dec.unit, data)) {

            //TODO: "object" declarations?
            value fdv = FindDeclarationNodeVisitor(dec);
            phasedUnit.compilationUnit.visit(fdv);
            assert (is Tree.Declaration? decNode = fdv.declarationNode);
            if (exists decNode) {
                addRemoveAnnotationProposalInternal(annotation, desc, dec,
                    phasedUnit, decNode, data);
            }
        }
    }
    
    void addRemoveAnnotationProposalInternal(String annotation, String desc,
        Declaration dec, PhasedUnit unit, Tree.Declaration decNode, Data data) {
        value change = newTextChange(desc, unit);
        initMultiEditChange(change);

        value offset = decNode.startIndex;
        for (a in CeylonIterable(decNode.annotationList.annotations)) {
            assert (is Tree.BaseMemberExpression bme = a.primary);
            Tree.Identifier? id = bme.identifier;
            if (exists id) {
                if (id.text.equals(annotation)) {
                    Tree.PositionalArgumentList? pal = a.positionalArgumentList;
                    value args = (pal?.token exists || a.namedArgumentList exists);
                    addEditToChange(change, newDeleteEdit(a.startIndex.intValue(),
                        a.endIndex.intValue() - a.startIndex.intValue()
                                 + (if (args) then 0 else 1))); //get rid of the trailing space
                }
            }
        }
        
        value newDesc = description(annotation, dec);
        value selection = newRegion(offset.intValue(), 0);
        newRemoveAnnotationQuickFix(dec, annotation, 
            newDesc, offset.intValue(), change, selection, data);
    }
    
    String description(String annotation, Declaration dec) {
        variable String? name = dec.name;
        if (!exists n = name) {
            if (ModelUtil.isConstructor(dec)) {
                name = "default constructor ";
            } else {
                name = "";
            }
        } else {
            assert(exists n = name);
            name = "'" + n + "' ";
        }
        
        assert(exists _name = name);
        
        variable value descr = "Make " + _name + "non-" + annotation;
        value container = dec.container;
        if (is ClassOrInterface container) {
            value td = container;
            descr += " in '"+td.name+"'";
        }
        
        return descr;
    }

    
    shared void addRemoveAnnotationDecProposal(String annotation, Project project, Node node, Data data) {
        if (is Tree.Declaration node) {
            value decNode = node;
            addRemoveAnnotationProposal2(node, annotation, "Make Non" + annotation, decNode.declarationModel, project, data);
        }
    }
}
