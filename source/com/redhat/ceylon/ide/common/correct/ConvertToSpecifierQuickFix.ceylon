import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}

shared interface ConvertToSpecifierQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared void addConvertToSpecifierProposal(Data data, IFile file, Tree.Block? block,
        Boolean anonymousFunction = false) {
     
        if (exists block,
            block.statements.size() == 1) {
         
            value s = block.statements.get(0);
            variable Node? end = null;
            variable Node? start = null;
            
            if (is Tree.Return s) {
                value ret = s;
                start = ret.expression;
                end = start;
            } else if (is Tree.ExpressionStatement s) {
                value es = s;
                start = es.expression;
                end = start;
            } else if (is Tree.SpecifierStatement s) {
                value ss = s;
                start = ss.baseMemberExpression;
                end = ss.specifierExpression;
            }
            
            if (exists en = end, exists st = start) {
                value change = newTextChange("Convert to Specifier", file);
                initMultiEditChange(change);
                value offset = block.startIndex.intValue();
                value es = getDocContent(getDocumentForChange(change),
                    st.startIndex.intValue(), 
                    en.endIndex.intValue() - st.startIndex.intValue());
                
                addEditToChange(change, 
                    newReplaceEdit(offset, 
                        block.endIndex.intValue() - offset,
                        "=> " + es + (if (anonymousFunction) then "" else ";"))
                );
                value desc = if (anonymousFunction) 
                             then "Convert anonymous function body to =>" 
                             else "Convert block to =>";
                
                newProposal(data, desc, change, DefaultRegion(offset + 2, 0));
            }
        }
    }
}
