import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    DeleteEdit
}

shared object fillInArgumentNameQuickFix {

    shared void addFillInArgumentNameProposal(QuickFixData data, Tree.SpecifiedArgument sa) {
        value id = sa.identifier;
        if (!id.token exists) {
            value change 
                    = platformServices.createTextChange {
                name = "Fill in argument name";
                input = data.phasedUnit;
            };
            change.initMultiEdit();

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
                        value startIndex 
                                = fa.parameterLists
                                    .get(0)
                                    .startIndex;
                        if (!fa.type.token exists) {
                            //only really necessary if the anon 
                            //function has a block instead of => 
                            change.addEdit(InsertEdit {
                                start = startIndex.intValue();
                                text = "function ";
                            });
                        }
                        
                        change.addEdit(InsertEdit {
                            start = startIndex.intValue();
                            text = name;
                        });
                        
                        try {
                            //if it is an anon function with a body,
                            //we must remove the trailing ; which is
                            //required by the named arg list syntax
                            if (fa.block exists) {
                                value offset = sa.endIndex.intValue() - 1;
                                value doc = change.document;
                                
                                if (doc.getText(offset, 1) == ";") {
                                    change.addEdit(DeleteEdit(offset, 1));
                                }
                            }
                        } catch (Exception ex) {
                        }
                    }
                } else {
                    //convert other args to specified named args
                    //i.e.     arg;
                    //becomes  name = arg;
                    change.addEdit(InsertEdit {
                        start = sa.startIndex.intValue();
                        text = name + " = ";
                    });
                }
                
                if (change.hasEdits) {
                    data.addQuickFix {
                        description = "Fill in argument name '``name``'";
                        change = change;
                    };
                }
            }
        }
    }
}