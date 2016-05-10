import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    types
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    TypedDeclaration,
    TypeDeclaration,
    Type,
    Declaration,
    Functional
}
import java.util {
    Collections,
    HashSet
}
import com.redhat.ceylon.ide.common.completion {
    appendParameter
}
shared interface ChangeRefiningTypeQuickType<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, TextChange change,
        DefaultRegion region);

    shared void addChangeRefiningTypeProposal(Data data, IFile file) {
        value decNode = nodes.findDeclaration(data.rootNode, data.node);
        if (is Tree.TypedDeclaration td = decNode) {
            value dec = td.declarationModel;
            value rd = types.getRefinedDeclaration(dec);

            //TODO: this can return the wrong member when
            //      there are multiple ... better to look
            //      at what RefinementVisitor does
            if (is TypedDeclaration rd) {
                assert(is TypeDeclaration decContainer = dec.container);
                assert(is TypeDeclaration rdContainer = rd.container);
                value supertype = decContainer.type.getSupertype(rdContainer);
                value ref = rd.appliedReference(supertype, Collections.emptyList<Type>());
                value t = ref.type;
                value type = t.asSourceCodeString(td.unit);
                value declarations = HashSet<Declaration>();

                importProposals.importType(declarations, t, data.rootNode);

                value change = newTextChange("Change Type", file);
                value offset = data.node.startIndex.intValue();
                value length = data.node.distance.intValue();
                initMultiEditChange(change);
                importProposals.applyImports(change, declarations, data.rootNode, getDocumentForChange(change));
                
                addEditToChange(change, newReplaceEdit(offset, length, type));
                
                value selection = DefaultRegion(offset, type.size);
                newProposal(data, "Change type to '" + type + "'", change, selection);
            }
        }
    }
    
    shared void addChangeRefiningParametersProposal(Data data, IFile file) {
        assert (is Tree.Statement decNode = nodes.findStatement(data.rootNode, data.node));
        
        Tree.ParameterList list;
        Declaration dec;
        
        if (is Tree.AnyMethod decNode) {
            value am = decNode;
            list = am.parameterLists.get(0);
            dec = am.declarationModel;
        } else if (is Tree.AnyClass decNode) {
            value ac = decNode;
            list = ac.parameterList;
            dec = ac.declarationModel;
        } else if (is Tree.SpecifierStatement decNode) {
            value ss = decNode;
            value lhs = ss.baseMemberExpression;
            if (is Tree.ParameterizedExpression lhs) {
                value pe = lhs;
                list = pe.parameterLists.get(0);
                dec = ss.declaration;
            } else {
                return;
            }
        } else {
            return;
        }
        
        variable Declaration rd = dec.refinedDeclaration;
        if (dec == rd) {
            rd = dec.container.getDirectMember(dec.name, null, false);
        }
        
        if (is Functional rf = rd, is Functional f = dec) {
            value rdPls = rf.parameterLists;
            value decPls = f.parameterLists;
            if (rdPls.empty || decPls.empty) {
                return;
            }
            
            value rdpl = rdPls.get(0).parameters;
            value dpl = decPls.get(0).parameters;
            value decContainer = dec.container;
            value rdContainer = rd.container;

            Type? supertype;
            if (is TypeDeclaration decContainer,
                is TypeDeclaration rdContainer) {
                supertype = decContainer.type.getSupertype(rdContainer);
            } else {
                supertype = null;
            }
            
            value pr = rd.appliedReference(supertype, Collections.emptyList<Type>());
            value params = list.parameters;
            value change = newTextChange("Fix Refining Parameter List", file);
            initMultiEditChange(change);
            
            value unit = decNode.unit;
            value declarations = HashSet<Declaration>();
            variable value i = 0;
            
            while (i < params.size()) {
                value p = params.get(i);
                if (rdpl.size() <= i) {
                    value start = if (i == 0)
                                  then list.startIndex.intValue() + 1
                                  else params.get(i - 1).endIndex.intValue();
                    value stop = params.get(params.size() - 1).endIndex.intValue();
                    addEditToChange(change, newDeleteEdit(start, stop - start));
                    break;
                } else {
                    value rdp = rdpl.get(i);
                    value pt = pr.getTypedParameter(rdp).fullType;
                    value dt = dpl.get(i).model.typedReference.fullType;
                    if (!dt.isExactly(pt)) {
                        addEditToChange(change, 
                            newReplaceEdit(p.startIndex.intValue(), 
                                p.distance.intValue(),
                                //TODO: better handling for callable parameters
                                pt.asSourceCodeString(unit) + " " + rdp.name)
                        );
                        importProposals.importType(declarations, pt, data.rootNode);
                    }
                }
                
                i++;
            }
            
            if (rdpl.size() > params.size()) {
                value buf = StringBuilder();
                variable value j = params.size();
                while (j < rdpl.size()) {
                    value rdp = rdpl.get(j);
                    if (j > 0) {
                        buf.append(", ");
                    }
                    
                    appendParameter(buf, pr, rdp, unit, false);
                    value pt = pr.getTypedParameter(rdp).fullType;
                    importProposals.importType(declarations, pt, data.rootNode);
                    j++;
                }
                
                value offset = if (params.empty) 
                               then list.startIndex.intValue() + 1
                               else params.get(params.size() - 1).endIndex.intValue();
                
                addEditToChange(change, newInsertEdit(offset, buf.string));
            }
            
            importProposals.applyImports(change, declarations, data.rootNode,
                getDocumentForChange(change));
            
            if (hasChildren(change)) {
                value selection = DefaultRegion(list.startIndex.intValue() + 1, 0);
                newProposal(data, "Fix refining parameter list", change, selection);
            }
        }
    }
}
