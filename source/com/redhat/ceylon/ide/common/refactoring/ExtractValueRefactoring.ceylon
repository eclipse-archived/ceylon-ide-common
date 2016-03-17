import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.correct {
    ImportProposals,
    DocumentChanges
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Declaration
}

import java.lang {
    StringBuilder
}
import java.util {
    HashSet
}


shared interface ExtractValueRefactoring<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange, IRegion=DefaultRegion>
        satisfies ExtractInferrableTypedRefactoring<TextChange>
        & NewNameRefactoring
        & DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
        & ExtractLinkedModeEnabled<IRegion>
        given InsertEdit satisfies TextEdit {

    shared formal ImportProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange> importProposals;

    shared formal actual variable Boolean canBeInferred;
    shared formal actual variable Type? type;
    shared formal variable Boolean getter;

    value indents => importProposals.indents;

    initialNewName()
            => if (exists node = editorData?.node)
               then nodes.nameProposals(node, false, editorData?.rootNode).get(0).string
               else "";
    
    enabled => if (exists node = editorData?.node,
                   exists sourceFile = editorData?.sourceVirtualFile,
                   editable &&
                   sourceFile.name != "module.ceylon" &&
                   sourceFile.name != "package.ceylon" &&
                   node is Tree.Term)
               then true
               else false;
    
    shared Boolean extractsFunction
            => if (is Tree.Term term = editorData?.node) 
            then unparenthesize(term) is Tree.FunctionArgument 
            else false;
    
    function applyImports(Tree.CompilationUnit rootNode, TextChange tfc, IDocument doc) {
        value decs = HashSet<Declaration>();
        importProposals.importType(decs, type, rootNode);
        return importProposals.applyImports(tfc, decs, rootNode, doc);
    }
    
    shared actual void build(TextChange tfc) {
        "This method will only be called when the [[editorData]]is not [[null]]"
        assert (exists editorData = this.editorData,
                exists sourceFile = editorData.sourceVirtualFile,
                is Tree.Term node = editorData.node);
        
        initMultiEditChange(tfc);
        value doc = getDocumentForChange(tfc);
        value tokens = editorData.tokens;
        value rootNode = editorData.rootNode;
        value unit = node.unit;
        assert (exists statement = nodes.findStatement(rootNode, node));
        
        variable Tree.FunctionArgument? result = null;
        object extends Visitor() {
            shared actual void visit(Tree.FunctionArgument that) {
                if (that != node &&
                    that.startIndex.intValue() <= node.startIndex.intValue() &&
                    that.endIndex.intValue() >= node.endIndex.intValue() &&
                    that.startIndex.intValue() > statement.startIndex.intValue()) {
                    result = that;
                }
                super.visit(that);
            }
        }.visit(statement);

        value indent = 
                indents.getDefaultLineDelimiter(doc) + 
                indents.getIndent(statement, doc);     
        Boolean toplevel;
        Integer adjustment;
        Integer start;
        String newLineOrReturn;
        if (exists anon = result, !anon.block exists,
            exists ex = anon.expression) {
            //we have a fat arrow anonymous function
            //we need to convert the fat arrow to a 
            //block with a return statement
            value pls = anon.parameterLists;
            value pl 
                    = if (exists tcl 
                            = anon.typeConstraintList)
                    then tcl else pls.get(pls.size()-1);
            start = ex.startIndex.intValue();
            value loc = pl.endIndex.intValue();
            value len = ex.startIndex.intValue() - loc;
            value end = ex.endIndex.intValue();
            addEditToChange(tfc, newReplaceEdit(loc, len, " { "));
            addEditToChange(tfc, newInsertEdit(end, "; }"));
            adjustment = 3-len;
            newLineOrReturn = 
                    if (anon.declarationModel.declaredVoid) 
                    then " " else " return ";
            toplevel = false;
        }
        else if (is Tree.MethodDeclaration fun = statement,
                 exists se = fun.specifierExpression,
                 exists ex = se.expression) {
            //we have a fat arrow regular function
            //we need to convert the fat arrow to a 
            //block with a return statement
            value pls = fun.parameterLists;
            value pl 
                    = if (exists tcl 
                            = fun.typeConstraintList)
                    then tcl else pls.get(pls.size()-1);
            start = ex.startIndex.intValue();
            value loc = pl.endIndex.intValue();
            value len = ex.startIndex.intValue() - loc;
            value end = ex.endIndex.intValue();
            value semi = fun.endIndex.intValue()-1;
            String starting = " {" + indent + indents.defaultIndent;
            String ending = ";" + indent + "}";
            addEditToChange(tfc, newReplaceEdit(loc, len, starting));
            addEditToChange(tfc, newInsertEdit(end, ending));
            addEditToChange(tfc, newDeleteEdit(semi, 1));
            adjustment = starting.size-len;
            newLineOrReturn = 
                    indent + indents.defaultIndent +
                    (!fun.declarationModel.declaredVoid then "return " else "");
            toplevel = false;
        }
        else {
            start = statement.startIndex.intValue();
            adjustment = 0;
            newLineOrReturn = indent;
            toplevel 
                    = if (is Tree.Declaration dec = statement) 
                    then dec.declarationModel.toplevel 
                    else false;
        }
        
        String modifiers;
        String body;
        value core = unparenthesize(node);
        if (is Tree.FunctionArgument core) {
            //we're extracting an anonymous function, so
            //actually we're going to create a function
            //instead of a value
            type = unit.denotableType(core.type.typeModel);
            
            value voidModifier = core.type is Tree.VoidModifier;
            modifiers = voidModifier then "void" else "function";
            
            value bodyWithParams = StringBuilder();
            nodes.appendParameters(bodyWithParams, core, unit, tokens);
            if (exists block = core.block) {
                bodyWithParams.append(" ").append(nodes.text(block, tokens));
            }
            else if (exists expr = core.expression) {
                bodyWithParams.append(" => ").append(nodes.text(expr, tokens)).append(";");
            }
            else {
                bodyWithParams.append(" => ");
            }
            body = bodyWithParams.string;
        }
        //TODO: add a special case for object expressions
        else {
            type = unit.denotableType(core.typeModel);
            modifiers = "value";
            value specifier = getter then " => " else " = ";
            body = specifier + nodes.text(core, tokens) + ";";
        }

        String typeDec;
        Integer shift;
        if (exists type = this.type, !type.unknown) {
            if (explicitType || toplevel) {
                typeDec = type.asSourceCodeString(unit);
                shift = adjustment + applyImports(rootNode, tfc, doc);
            }
            else {
                canBeInferred = true;
                typeDec = modifiers;
                shift = adjustment;
            }
        }
        else {
            typeDec = "dynamic";
            shift = adjustment;
        }
        
        value definition = 
                typeDec + " " + newName + 
                body + 
                newLineOrReturn;
        
        value tlength = typeDec.size;
        value nstart = nodes.getNodeStartOffset(node);
        value nlength = node.distance.intValue();
        addEditToChange(tfc, newInsertEdit(start, definition));
        addEditToChange(tfc, newReplaceEdit(nstart, nlength, newName));
        value len = newName.size;
        typeRegion = newRegion(start + adjustment, tlength);
        decRegion = newRegion(start + adjustment + tlength + 1, len);
        refRegion = newRegion(nstart + adjustment + definition.size, len);
    }
    
    forceWizardMode()
            => if (exists node = editorData?.node,
                   exists scope = node.scope)
               then scope.getMemberOrParameter(node.unit, newName, null, false) exists
               else false;

    nameProposals
            => nodes.nameProposals(editorData?.node, false, editorData?.rootNode);

    name => "Extract Value";
}
