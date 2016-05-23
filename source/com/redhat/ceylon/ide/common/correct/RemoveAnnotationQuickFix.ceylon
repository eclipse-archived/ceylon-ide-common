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
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    DeleteEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.model {
    AnyProjectSourceFile
}

shared object removeAnnotationQuickFix {
    
    shared void addRemoveAnnotationProposal(Node node, String annotation, QuickFixData data) {
        if (is Declaration dec = nodes.getReferencedDeclaration(node)) {
            addRemoveAnnotationProposal2(node, annotation, "Make Non" + annotation, dec, data);
        }
    }
    
    shared void addMakeContainerNonfinalProposal(Node node, QuickFixData data) {
        Declaration dec;
        if (is Tree.Declaration node) {
            if (is Declaration container = node.declarationModel.container) {
                dec = container;
            } else {
                return;
            }
        } else {
            assert(is Declaration scope = node.scope);
            dec = scope;
        }
        addRemoveAnnotationProposal2(node, "final", "Make Nonfinal", dec, data);
    }
    
    void addRemoveAnnotationProposal2(Node node, String annotation, String desc,
        Declaration? dec, QuickFixData data) {
        
        if (exists dec,
            exists d = dec.name,
            is AnyProjectSourceFile unit = dec.unit,
            exists phasedUnit = unit.phasedUnit) {

            //TODO: "object" declarations?
            value fdv = FindDeclarationNodeVisitor(dec);
            phasedUnit.compilationUnit.visit(fdv);
            if (exists decNode = fdv.declarationNode) {
                assert (is Tree.Declaration decNode);
                addRemoveAnnotationProposalInternal(annotation, desc, dec,
                    phasedUnit, decNode, data);
            }
        }
    }
    
    void addRemoveAnnotationProposalInternal(String annotation, String desc,
        Declaration dec, PhasedUnit unit, Tree.Declaration decNode, QuickFixData data) {
        value change = platformServices.document.createTextChange(desc, unit);
        change.initMultiEdit();

        value offset = decNode.startIndex;
        for (a in decNode.annotationList.annotations) {
            assert (is Tree.BaseMemberExpression bme = a.primary);
            if (exists id = bme.identifier) {
                if (id.text.equals(annotation)) {
                    value args = a.positionalArgumentList?.token exists || a.namedArgumentList exists;
                    change.addEdit(DeleteEdit(a.startIndex.intValue(),
                        a.endIndex.intValue() - a.startIndex.intValue()
                                 + (if (args) then 0 else 1))); //get rid of the trailing space
                }
            }
        }
        
        value newDesc = description(annotation, dec);
        value selection = DefaultRegion(offset.intValue(), 0);
        data.addQuickFix(newDesc, change, selection);
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
        if (is ClassOrInterface container = dec.container) {
            value td = container;
            descr += " in '"+td.name+"'";
        }
        
        return descr;
    }

    
    shared void addRemoveAnnotationDecProposal(String annotation, Node node, QuickFixData data) {
        if (is Tree.Declaration node) {
            addRemoveAnnotationProposal2(node, annotation, "Make Non" + annotation, node.declarationModel, data);
        }
    }
}
