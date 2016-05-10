import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

shared interface AddNamedArgumentQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {
    
    shared formal void newProposal(Data data, String desc, TextChange change,
        DefaultRegion region);
    
    shared void addNamedArgumentsProposal(Data data, IFile file) {
        if (is Tree.NamedArgumentList node = data.node) {
            value tfc = newTextChange("Add Named Arguments", file);
            value doc = getDocumentForChange(tfc);
            initMultiEditChange(tfc);
            
            value nal = node;
            value args = nal.namedArgumentList;
            value start = nal.startIndex.intValue();
            value stop = nal.endIndex.intValue() - 1;
            variable value loc = start + 1;
            variable value sep = " ";
            value nas = nal.namedArguments;
            
            if (!nas.empty) {
                value last = nas.get(nas.size() - 1);
                loc = last.endIndex.intValue();
                value firstLine = getLineOfOffset(doc, start);
                value lastLine = getLineOfOffset(doc, stop);
                
                if (firstLine != lastLine) {
                    sep = indents.getDefaultLineDelimiter(doc) 
                            + indents.getIndent(last, doc);
                }
            }
            
            value params = args.parameterList;
            variable String? result = null;
            variable value multipleResults = false;
            for (param in params.parameters) {
                if (!param.defaulted, !args.argumentNames.contains(param.name)) {
                    multipleResults = result exists;
                    result = param.name;
                    addEditToChange(tfc, newInsertEdit(loc, sep + param.name + " = nothing;"));
                }
            }
            
            if (loc == stop) {
                addEditToChange(tfc, newInsertEdit(stop, " "));
            }
            
            value name = if (multipleResults)
                         then "Fill in missing named arguments"
                         else "Fill in missing named argument '" + (result else "") + "'";
            
            newProposal(data, name, tfc, DefaultRegion(loc, 0));
        }
    }
}
