import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    ReplaceEdit,
    commonIndents
}

shared object convertForToWhileQuickFix {
 
    shared void addConvertForToWhileProposal(QuickFixData data,
        Tree.Statement? statement) {
     
        if (is Tree.ForStatement forSt = statement, 
            is Tree.ValueIterator fi = forSt.forClause?.forIterator,
            exists e = fi.specifierExpression?.expression) {
            
            value doc = data.doc;
            value change = platformServices.createTextChange { 
                desc = "Convert For to While";
                input = data.phasedUnit;
            };
            change.initMultiEdit();
            
            change.addEdit(
                InsertEdit {
                    start = forSt.startIndex.intValue();
                    text = "value it = "
                        + doc.getText(e.startIndex.intValue(), e.distance.intValue())
                        + ".iterator();" 
                        + commonIndents.getDefaultLineDelimiter(doc)
                        + commonIndents.getIndent(forSt, doc);
                });
            change.addEdit(
                ReplaceEdit {
                    start = forSt.startIndex.intValue();
                    length = 3;
                    text = "while";
                });
            change.addEdit(
                ReplaceEdit {
                    start = fi.startIndex.intValue()+1;
                    length = fi.distance.intValue()-2;
                    text = "!is Finished " 
                            + fi.variable.identifier.text 
                            + " = it.next()";
                });
               
            data.addQuickFix("Convert 'for' loop to 'while'", change);
        }
    }
    
}
