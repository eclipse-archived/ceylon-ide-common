import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
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

    class FindAnonFunctionVisitor(statement, Node node) extends Visitor() {
        Tree.Statement statement;
        shared variable Tree.FunctionArgument? result = null;
        
        shared actual void visit(Tree.FunctionArgument that) {
            if (that != node &&
                that.startIndex.intValue() <= node.startIndex.intValue() &&
                    that.endIndex.intValue()>=node.endIndex.intValue() &&
                    that.startIndex.intValue()>statement.startIndex.intValue()) {
                result = that;
            }
            super.visit(that);
        }
    }

    shared formal ImportProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange> importProposals;

    shared formal actual variable Boolean canBeInferred;
    shared formal actual variable Type? type;
    shared formal variable Boolean getter;

    value indents => importProposals.indents;

    initialNewName()
            => if (exists node = editorData?.node)
               then nodes.nameProposals(node, false, editorData?.rootNode).get(0).string
               else "";

    editable => true;
            /*
             TODO : This should be uncommented and implemented here when EditedSourceFile
             will be made available.

             rootNode?.unit is EditedSourceFile<Nothing, Nothing, Nothing, Nothing> ||
             rootNode?.unit is ProjectSourceFile<Nothing, Nothing, Nothing, Nothing>;
             */

    enabled => if (exists data=editorData,
                   exists sourceFile=data.sourceVirtualFile,
                   editable &&
                   sourceFile.name != "module.ceylon" &&
                   sourceFile.name != "package.ceylon" &&
                   data.node is Tree.Term)
               then true
               else false;

    shared actual void build(TextChange tfc) {
        "This method will only be called when the [[editorData]]is not [[null]]"
        assert (exists data=editorData,
                exists sourceFile=data.sourceVirtualFile,
                is Tree.Term node=data.node);

        initMultiEditChange(tfc);
        value doc = getDocumentForChange(tfc);
        value rootNode = data.rootNode;
        value unit = node.unit;
        assert (exists statement = nodes.findStatement(rootNode, node));
        
        variable value start = statement.startIndex.intValue();
        variable Integer il = 0;
        variable String newLineOrReturn = 
                indents.getDefaultLineDelimiter(doc) + 
                indents.getIndent(statement, doc);
        
        value visitor = FindAnonFunctionVisitor(statement, node);
        visitor.visit(statement);

        Boolean toplevel;
        if (exists anon = visitor.result, !anon.block exists) {
            if (exists ex = anon.expression) {
                value pls = anon.parameterLists;
                variable Node pl = pls.get(pls.size()-1);
                if (exists tcl = anon.typeConstraintList) {
                    pl = tcl;
                }
                start = ex.startIndex.intValue();
                value loc = pl.endIndex.intValue();
                value len = ex.startIndex.intValue() - loc;
                value end = ex.endIndex.intValue();
                addEditToChange(tfc, newReplaceEdit(loc, len, " { "));
                addEditToChange(tfc, newInsertEdit(end, "; }"));
                il -=len-3;
                if (anon.declarationModel.declaredVoid) {
                    newLineOrReturn = " ";
                }
                else {
                    newLineOrReturn = " return ";
                }
                toplevel = false;
            }
            else {
                return;
            }
        }
        else if (is Tree.Declaration dec = statement) {
            if (is Tree.MethodDeclaration md=dec) {
                if (exists se = md.specifierExpression) {
                    if (exists ex = se.expression) {
                        value pls = md.parameterLists;
                        variable Node pl = pls.get(pls.size()-1);
                        if (exists tcl=md.typeConstraintList) {
                            pl = tcl;
                        }
                        start = ex.startIndex.intValue();
                        value loc = pl.endIndex.intValue();
                        value len = ex.startIndex.intValue() - loc;
                        value end = ex.endIndex.intValue();
                        value semi = dec.endIndex.intValue()-1;
                        String indent = indents.defaultIndent;
                        String starting = " {" + newLineOrReturn + indent;
                        String ending = ";" + newLineOrReturn + "}";
                        addEditToChange(tfc, newReplaceEdit(loc, len, starting));
                        addEditToChange(tfc, newInsertEdit(end, ending));
                        addEditToChange(tfc, newDeleteEdit(semi, 1));
                        il-=len-starting.size;
                        newLineOrReturn = newLineOrReturn + indent;
                        if (!md.declarationModel.declaredVoid) {
                            newLineOrReturn += "return ";
                        }
                    }
                }
                toplevel = false;
            }
            else {
                toplevel = dec.declarationModel.toplevel;
            }
        }
        else {
            toplevel = false;
        }
        type = unit.denotableType(node.typeModel);
        value unparened = unparenthesize(node);

        value anonFunction =
                if (is Tree.FunctionArgument unparened)
                then unparened
                else null;

        String mod;
        String exp;
        if (exists fa = anonFunction) {
            type = unit.getCallableReturnType(type);
            value sb = StringBuilder();
            
            mod = fa.type is Tree.VoidModifier then "void " else "function";
            nodes.appendParameters(sb, fa, unit, this);

            if (exists block = fa.block) {
                sb.append(" ").append(toString(block));
            }
            else if (exists expr = fa.expression) {
                sb.append(" => ").append(toString(expr)).append(";");
            }
            else {
                sb.append(" => ");
            }
            exp = sb.string;
        }
        else {
            mod = "value";
            exp = toString(unparened) + ";";
        }

        String typeDec;
        if (type?.unknown else true) {
            typeDec = "dynamic";
            il = 0;
        }
        else if (exists t = type, explicitType || toplevel) {
            typeDec = t.asSourceCodeString(unit);
            value declarations = HashSet<Declaration>();
            importProposals.importType(declarations, type, rootNode);
            il += importProposals.applyImports(tfc, declarations, rootNode, doc);
        }
        else {
            canBeInferred = true;
            typeDec = mod;
        }

        value myDeclaration =
            "``typeDec`` ``newName````
                if (anonFunction exists)
                then ""
                else if (getter) then " => " else " = "
                ````exp``";

        value text = myDeclaration + newLineOrReturn;
        value tlength = typeDec.size;
        value nstart = nodes.getNodeStartOffset(node);
        value nlength = node.distance.intValue();
        addEditToChange(tfc, newInsertEdit(start, text));
        addEditToChange(tfc, newReplaceEdit(nstart, nlength, newName));
        value len = newName.size;
        typeRegion = newRegion(start+il, tlength);
        decRegion = newRegion(start+il+tlength+1, len);
        refRegion = newRegion(nstart+il+text.size, len);
    }

    shared Boolean isFunction
        => editorData?.node is Tree.FunctionArgument;

    forceWizardMode()
            => if (exists data = editorData,
                   exists node = data.node,
                   exists scope = node.scope)
               then scope.getMemberOrParameter(node.unit, newName, null, false) exists
               else false;

    nameProposals
            => nodes.nameProposals(editorData?.node, false, editorData?.rootNode);

    name => "Extract Value";
}
