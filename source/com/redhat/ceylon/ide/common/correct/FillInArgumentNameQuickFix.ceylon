import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

shared interface FillInArgumentNameQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {

    shared void addFillInArgumentNameProposal(Data data, IFile file, Tree.SpecifiedArgument sa) {
        value id = sa.identifier;
        if (!id.token exists) {
            value change = newTextChange("Fill in argument name", file);
            initMultiEditChange(change);

            if (exists e = sa.specifierExpression.expression) {
                value name = id.text;
                if (is Tree.FunctionArgument fa = e.term) {
                    //convert anon functions to typed named argument
                    //i.e.     (Param param) => result;
                    //becomes  function fun(Param param) => result;
                    //and      (Param param) { return result; };
                    //becomes  function fun(Param param) { return result; }
                    //and      void (Param param) {};
                    //becomes  void fun(Param param) {}
                    if (!fa.parameterLists.empty) {
                        value startIndex = fa.parameterLists.get(0).startIndex;
                        if (!fa.type.token exists) {
                            //only really necessary if the anon 
                            //function has a block instead of => 
                            addEditToChange(change, newInsertEdit(startIndex.intValue(), "function "));
                        }
                        
                        addEditToChange(change, newInsertEdit(startIndex.intValue(), name));
                        
                        try {
                            //if it is an anon function with a body,
                            //we must remove the trailing ; which is
                            //required by the named arg list syntax
                            if (fa.block exists) {
                                value offset = sa.endIndex.intValue() - 1;
                                value doc = getDocumentForChange(change);
                                
                                if (getDocContent(doc, offset, 1) == ";") {
                                    addEditToChange(change, newDeleteEdit(offset, 1));
                                }
                            }
                        } catch (Exception ex) {
                        }
                    }
                } else {
                    //convert other args to specified named args
                    //i.e.     arg;
                    //becomes  name = arg;
                    addEditToChange(change, newInsertEdit(sa.startIndex.intValue(), name + " = "));
                }
                
                if (hasChildren(change)) {
                    value desc = "Fill in argument name '" + name + "'";
                    newProposal(data, desc, change);
                }
            }
        }
    }
}