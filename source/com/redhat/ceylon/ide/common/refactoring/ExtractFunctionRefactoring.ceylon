//import com.redhat.ceylon.compiler.typechecker.tree {
//    Tree
//}
//import com.redhat.ceylon.ide.common.util {
//    nodes
//}
//import com.redhat.ceylon.model.typechecker.model {
//    Type,
//    Declaration
//}
//
//import java.util {
//    HashSet
//}
//import java.lang {
//    StringBuilder,
//    ObjectArray,
//    JString=String
//}
//import com.redhat.ceylon.ide.common.correct {
//    ImportProposals,
//    DocumentChanges
//}
//
//
//shared interface ExtractFunctionRefactoring<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange, IRegion=DefaultRegion>
//        satisfies ExtractInferrableTypedRefactoring<TextChange>
//        & NewNameRefactoring
//        & DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
//        & ExtractLinkedModeEnabled<IRegion>
//        given InsertEdit satisfies TextEdit {
//
//    shared formal ImportProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange> importProposals;
//
//    shared formal actual variable Boolean canBeInferred;
//    shared formal actual variable Type? type;
//    shared formal variable Boolean getter;
//
//    value indents => importProposals.indents;
//
//    shared actual String initialNewName()
//            => if (exists node = editorData?.node)
//                then nodes.nameProposals(node).get(0).string
//                else "";
//
//    shared actual default Boolean editable
//            => true;
//            /*
//             TODO : This should be uncommented and implemented here when EditedSourceFile
//             will be made available.
//
//             rootNode?.unit is EditedSourceFile<Nothing, Nothing, Nothing, Nothing> ||
//             rootNode?.unit is ProjectSourceFile<Nothing, Nothing, Nothing, Nothing>;
//             */
//
//    shared actual Boolean enabled
//            => if (exists data=editorData,
//                    exists sourceFile=data.sourceVirtualFile,
//                    editable &&
//                    sourceFile.name != "module.ceylon" &&
//                    sourceFile.name != "package.ceylon" &&
//                    data.node is Tree.Term)
//                then true
//                else false;
//
//    shared actual void build(TextChange tfc) {
//        "This method will only be called when the [[editorData]]is not [[null]]"
//        assert(exists data=editorData,
//            exists sourceFile=data.sourceVirtualFile,
//            exists rootNode=data.rootNode,
//            is Tree.Term node=data.node);
//
//        initMultiEditChange(tfc);
//        value doc = getDocumentForChange(tfc);
//
//        value unit = node.unit;
//        value statement = nodes.findStatement(rootNode, node);
//        value toplevel = if (is Tree.Declaration statement)
//        then statement.declarationModel.toplevel
//        else false;
//        type = unit.denotableType(node.typeModel);
//        value unparened = unparenthesize(node);
//
//        String mod;
//        String exp;
//
//        Tree.FunctionArgument? anonFunction =
//                if (is Tree.FunctionArgument unparened)
//        then unparened
//        else null;
//
//        if (exists fa = anonFunction) {
//            type = unit.getCallableReturnType(type);
//            StringBuilder sb = StringBuilder();
//
//            mod = if (is Tree.VoidModifier t = fa.type) then "void " else "function";
//            nodes.appendParameters(sb, fa, unit, this);
//
//            if (exists block = fa.block) {
//                sb.append(" ").append(toString(block));
//            } else if (exists expr = fa.expression) {
//                sb.append(" => ").append(toString(expr)).append(";");
//            } else {
//                sb.append(" => ");
//            }
//            exp = sb.string;
//        } else {
//            mod = "value";
//            exp = toString(unparened) + ";";
//        }
//
//        variable String typeDec;
//
//        Integer il;
//        if (type?.unknown else true) {
//            typeDec = "dynamic";
//            il = 0;
//        } else if (exists t = type, explicitType || toplevel) {
//            typeDec = t.asSourceCodeString(unit);
//            value declarations = HashSet<Declaration>();
//            importProposals.importType(declarations, type, rootNode);
//            il = importProposals.applyImports(tfc, declarations, rootNode, doc);
//        } else {
//            canBeInferred = true;
//            typeDec = mod;
//            il = 0;
//        }
//
//        value myDeclaration =
//            "``typeDec`` ``newName````
//                if (anonFunction exists)
//                then ""
//                else if (getter) then " => " else " = "
//                ````exp``";
//
//        value text = myDeclaration + indents.getDefaultLineDelimiter(doc)
//                + indents.getIndent(statement, doc);
//
//        if (exists st = statement) {
//            Integer start = st.startIndex.intValue();
//
//            addEditToChange(tfc, newInsertEdit(start, text));
//            addEditToChange(tfc, newReplaceEdit(nodes.getNodeStartOffset(node), nodes.getNodeLength(node), newName));
//            typeRegion = newRegion(start+il, typeDec.size);
//            decRegion = newRegion(start+il+typeDec.size+1, newName.size);
//            refRegion = newRegion(nodes.getNodeStartOffset(node)+il+text.size,
//                newName.size);
//        }
//    }
//
//    shared Boolean isFunction
//        => editorData?.node is Tree.FunctionArgument;
//
//    shared actual Boolean forceWizardMode()
//        => if (exists data = editorData,
//        exists node = data.node,
//        exists scope = node.scope)
//    then scope.getMemberOrParameter(node.unit, newName, null, false) exists
//    else false;
//
//    shared actual ObjectArray<JString> nameProposals
//        => nodes.nameProposals(editorData?.node);
//
//    shared actual String name
//        => "Extract Value";
//}
//
//
