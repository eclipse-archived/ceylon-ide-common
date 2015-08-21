import java.util{
    JArrayList=ArrayList,
    JCollection=Collection,
    JHashSet=HashSet,
    JIterator=Iterator,
    JList=List,
    JMap=Map,
    JSet=Set,
    Collections
}
import java.lang {
    JIterable=Iterable,
    JInteger=Integer
}
import com.redhat.ceylon.compiler.typechecker.tree{Node,
    Tree
}
import com.redhat.ceylon.ide.common.completion{
    FindImportNodeVisitor
}
import com.redhat.ceylon.ide.common.util{
    Escaping { escapeName, escapePackageName },
    nodes,
    Indents
}

import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Functional,
    Function,
    FunctionOrValue,
    Module { LANGUAGE_MODULE_NAME },
    Package,
    Parameter,
    ParameterList,
    Type,
    TypeDeclaration,
    TypedDeclaration
}
import ceylon.interop.java {
    CeylonIterable
}
import ceylon.collection {
    HashSet,
    unlinked
}


shared interface ImportProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange>
        given InsertEdit satisfies TextEdit {
    shared formal Indents<IDocument> indents;

    shared void addImportProposals(Tree.CompilationUnit? rootNode, Node? node, JCollection<ICompletionProposal> proposals, IFile file){
        if(is Tree.BaseMemberOrTypeExpression | Tree.SimpleType node) {
            value id = nodes.getIdentifyingNode(node);
            if(exists id){
                assert(exists rootNode);
                value brokenName = id.text;
                value mod = rootNode.unit.\ipackage.\imodule;
                for(dec in findImportCandidates( mod, brokenName,  rootNode)){
                    value ip = createImportProposal(rootNode, file, dec);
                    if(exists ip){
                        proposals.add(ip);
                    }
                }
            }
        }
    }


    """This code replace the following original code of the Eclipse plugin :

            Set <Declaration> result = HashSet<Declaration> ();
            for(pkg in CeylonIterable(mod.allVisiblePackages)){
                if(!pkg.nameAsString.empty){
                    Declaration? member = pkg.getMember(name, null, false);
                    if(exists member){
                        result.add(member);
                    }
                }
            }
            return result;

       """
    Set<Declaration> findImportCandidates(Module mod, String name, Tree.CompilationUnit rootNode)
            => HashSet {
                    stability = unlinked;
                    elements
                        = CeylonIterable(mod.allVisiblePackages)
                            .filter((pkg) => !pkg.nameAsString.empty)
                            .map((pkg) => let(Declaration? d=pkg.getMember(name, null, false)) d)
                            .coalesced;
               };

    shared formal [TextChange, IDocument] getTextChangeAndDocument(IFile file);

    shared formal ICompletionProposal newImportProposal(String description, TextChange correctionChange);

    shared ICompletionProposal? createImportProposal(Tree.CompilationUnit rootNode, IFile file, Declaration declaration) {
        value [importChange, doc] = getTextChangeAndDocument(file);
        JList<InsertEdit> ies =
                importEdits(rootNode,
            Collections.singleton(declaration),
            null, null, doc);

        if (ies.empty) {
            return null;
        }

        for (InsertEdit ie in CeylonIterable(ies)) {
            addEditToChange(importChange, ie);
        }
        String proposedName = declaration.name;
        /*String brokenName = id.getText();
         if (!brokenName.equals(proposedName)) {
            change.addEdit(new ReplaceEdit(id.getStartIndex(), brokenName.length(),
                    proposedName));
         }*/
        String pname =
                declaration.unit.\ipackage
                .nameAsString;
        String description =
                "Add import of '`` proposedName ``' in package '`` pname ``'";
        return newImportProposal(description, importChange);
    }

    shared formal TextEdit newDeleteEdit(Integer start, Integer stop);

    shared formal TextEdit newReplaceEdit(Integer start, Integer stop, String text);

    shared formal InsertEdit newInsertEdit(Integer position, String text);

    shared formal void addEditToChange(TextChange change, TextEdit edit);

    shared formal String getInsertedText(InsertEdit edit);

    shared JList <InsertEdit> importEdits(
        Tree.CompilationUnit rootNode,
        JIterable<Declaration> declarations,
        JIterable<String>? aliases,
        Declaration? declarationBeingDeleted,
        IDocument? doc) {
        String delim = indents.getDefaultLineDelimiter(doc);
        JList <InsertEdit> result = JArrayList<InsertEdit> ();
        JSet<Package> packages = JHashSet<Package> ();
        for(Declaration declaration in CeylonIterable(declarations)){
            packages.add(declaration.unit.\ipackage);
        }
        for(Package p in CeylonIterable(packages)){
            StringBuilder text = StringBuilder();
            if(!exists aliases){
                for(d in CeylonIterable(declarations)){
                    if(d.unit.\ipackage == p){
                        text.appendCharacter(',').append(delim).append(indents.defaultIndent).append(escapeName(d));
                    }
                }
            }
            else {
                JIterator <String> aliasIter = aliases.iterator();
                for(d in CeylonIterable(declarations)){
                    String? theAlias = aliasIter.next();
                    if(d.unit.\ipackage == p){
                        text.append(",").append(delim).append(indents.defaultIndent);
                        if(exists theAlias, theAlias != d.name) {
                            text.append(theAlias).appendCharacter('=');
                        }
                        text.append(escapeName(d));
                    }
                }
            }
            Tree.Import? importNode = findImportNode(rootNode, p.nameAsString);
            if(exists importNode) {
                Tree.ImportMemberOrTypeList imtl = importNode.importMemberOrTypeList;
                if(imtl.importWildcard exists){
                    // Do Nothing
                }
                else {
                    Integer insertPosition = getBestImportMemberInsertPosition(importNode);
                    if(exists declarationBeingDeleted,
                        imtl.importMemberOrTypes.size() == 1,
                        imtl.importMemberOrTypes.get(0).declarationModel == declarationBeingDeleted) {
                        text.delete(0, 2);
                    }
                    result.add(newInsertEdit(insertPosition, text.string));
                }
            }
            else {
                Integer insertPosition = getBestImportInsertPosition(rootNode);
                text.delete(0, 2);
                text.insert(0,"import "+escapePackageName(p)+" {"+delim).append(delim + "}");
                if(insertPosition == 0){
                    text.append(delim);
                }
                else {
                    text.insert(0, delim);
                }
                result.add(newInsertEdit(insertPosition, text.string));
            }
        }
        return result;
    }

    shared JList<TextEdit> importEditForMove(
        Tree.CompilationUnit rootNode,
        JIterable<Declaration> declarations,
        JIterable<String>? aliases,
        String newPackageName,
        String oldPackageName,
        IDocument? doc) {

        value delim = indents.getDefaultLineDelimiter(doc);
        value result = JArrayList<TextEdit>();
        value set = JHashSet<Declaration>();
        for(Declaration d in CeylonIterable(declarations)) {
            set.add(d);
        }
        StringBuilder text = StringBuilder();
        if(!exists aliases){
            for(Declaration d in CeylonIterable(declarations)) {
                text.append(",").append(delim).append(indents.defaultIndent).append(d.name);
            }
        }
        else {
            JIterator<String> aliasIter = aliases.iterator();
            for(Declaration d in CeylonIterable(declarations)) {
                String? \ialias = aliasIter.next();
                text.append(",").append(delim).append(indents.defaultIndent);
                if(exists \ialias, \ialias != d.name) {
                    text.append(\ialias).appendCharacter('=');
                }
                text.append(d.name);
            }
        }
        Tree.Import? oldImportNode = findImportNode(rootNode, oldPackageName);
        if(exists oldImportNode) {
            Tree.ImportMemberOrTypeList? imtl = oldImportNode.importMemberOrTypeList;
            if (exists imtl) {
                variable value remaining = 0;
                for(imt in CeylonIterable(imtl.importMemberOrTypes)){
                    if(!set.contains(imt.declarationModel)){
                        remaining++;
                    }
                }
                if(remaining == 0){
                    assert(exists startIndex=oldImportNode.startIndex);
                    assert(exists stopIndex=oldImportNode.stopIndex);
                    value start = startIndex.intValue();
                    value stop = stopIndex.intValue();
                    result.add(newDeleteEdit(start, stop - start + 1));
                }
                else {
                    assert(exists startIndex=imtl.startIndex);
                    assert(exists stopIndex=imtl.stopIndex);
                    value start = startIndex.intValue();
                    value stop = stopIndex.intValue();
                    String formattedImport = formatImportMembers(delim, indents.defaultIndent, set, imtl);
                    result.add(newReplaceEdit(start, stop - start + 1, formattedImport));
                }
            }
        }
        value pack = rootNode.unit.\ipackage;
        if(pack.qualifiedNameString != newPackageName) {
            Tree.Import? importNode = findImportNode(rootNode, newPackageName);
            if(exists importNode){
                Tree.ImportMemberOrTypeList imtl = importNode.importMemberOrTypeList;
                if(imtl.importWildcard exists){
                    // Do Nothing
                }
                else {
                    Integer insertPosition = getBestImportMemberInsertPosition(importNode);
                    result.add(newInsertEdit(insertPosition, text.string));
                }
            }
            else {
                Integer insertPosition = getBestImportInsertPosition(rootNode);
                text.delete(0, 2);
                text.insert(0,"import "+newPackageName+" {"+delim).append(delim + "}");
                if(insertPosition == 0){
                    text.append(delim);
                }
                else {
                    text.insert(0, delim);
                }
                result.add(newInsertEdit(insertPosition, text.string));
            }
        }
        return result;
    }
    shared String formatImportMembers(String delim, String indent, JSet<Declaration> set, Tree.ImportMemberOrTypeList imtl) {
        StringBuilder sb = StringBuilder().append("{").append(delim);
        for(Tree.ImportMemberOrType imt in CeylonIterable(imtl.importMemberOrTypes)) {
            Declaration? dec = imt.declarationModel;
            if(!set.contains(dec)){
                sb.append(indent);
                if(exists theAlias = imt.\ialias){
                    String aliasText = theAlias.identifier.text;
                    sb.append(aliasText).appendCharacter('=');
                }
                value id = imt.identifier.text;
                sb.append(id).appendCharacter(',').append(delim);
            }
        }

        // The following line replace the previous Java version with
        // a Java StringBuilder :
        //
        //     sb.setLength(sb.length() - 1 - delim.length());
        sb.deleteTerminal(1 + delim.size);
        sb.append(delim).appendCharacter('}');
        return sb.string;
    }

    shared Integer getBestImportInsertPosition(Tree.CompilationUnit cu){
        JInteger? stopIndex = cu.importList.stopIndex;
        if(! exists stopIndex) {
            return 0;
        } else {
            return stopIndex.intValue() + 1;
        }
    }

    shared Tree.Import? findImportNode(Tree.CompilationUnit cu, String packageName){
        value visitor = FindImportNodeVisitor(packageName);
        cu.visit(visitor);
        return visitor.result;
    }

    shared Integer getBestImportMemberInsertPosition(Tree.Import importNode){
        value imtl = importNode.importMemberOrTypeList;
        if(exists wildcard = imtl.importWildcard){
            assert(exists startIndex=wildcard.startIndex);
            return startIndex.intValue();
        }
        else {
            value imts = imtl.importMemberOrTypes;
            if(imts.empty){
                assert(exists startIndex=imtl.startIndex);
                return startIndex.intValue() + 1;
            }
            else {
                assert(exists stopIndex=imts.get(imts.size() - 1).stopIndex);
                return stopIndex.intValue() + 1;
            }
        }
    }
    shared Integer applyImports(TextChange change, JSet<Declaration>|JMap<Declaration, String> declarations, Tree.CompilationUnit cu, IDocument? doc, Declaration? declarationBeingDeleted=null){
        variable Integer il = 0;
        JIterable<Declaration> decls;
        JIterable<String>? aliases;
        if(is JSet<Declaration> declarations) {
            decls = declarations;
            aliases = null;
        } else {
            decls = declarations.keySet();
            aliases = declarations.values();
        }
        for(ie in CeylonIterable(importEdits(cu, decls, aliases, declarationBeingDeleted, doc))){
            il+=getInsertedText(ie).size;
            addEditToChange(change, ie);
        }
        return il;
    }

    shared void importSignatureTypes(Declaration declaration, Tree .CompilationUnit rootNode, JSet<Declaration> declarations){
        if(is TypedDeclaration declaration){
            TypedDeclaration td = declaration;
            importType(declarations, td.type, rootNode);
        }
        if(is Functional declaration){
            Functional fun = declaration;
            for(ParameterList pl in CeylonIterable(fun.parameterLists)) {
                for(Parameter p in CeylonIterable(pl.parameters)) {
                    importSignatureTypes(p.model, rootNode, declarations);
                }
            }
        }
    }

    shared void importTypes(JSet<Declaration> declarations, JCollection<Type>? types, Tree.CompilationUnit rootNode){
        if(exists types) {
            for(type in CeylonIterable(types)){
                importType(declarations, type, rootNode);
            }
        }
    }
    shared void importType(JSet<Declaration> declarations, Type? type, Tree.CompilationUnit rootNode){
        if(exists type){
            if(type.unknown || type.nothing) {
                // Do Nothing
            }
            else if(type.union){
                for(t in CeylonIterable(type.caseTypes)) {
                    importType(declarations, t, rootNode);
                }
            }
            else if(type.intersection){
                for(t in CeylonIterable(type.satisfiedTypes)) {
                    importType(declarations, t, rootNode);
                }
            }
            else {
                importType(declarations, type.qualifyingType, rootNode);
                TypeDeclaration td = type.declaration;
                if(type.classOrInterface && td.toplevel){
                    importDeclaration(declarations, td, rootNode);
                    for(Type arg in CeylonIterable(type.typeArgumentList)){
                        importType(declarations, arg, rootNode);
                    }
                }
            }
        }
    }

    shared void importDeclaration(JSet<Declaration> declarations, Declaration declaration, Tree.CompilationUnit rootNode) {
        if(!declaration.parameter) {
            value p = declaration.unit.\ipackage;
            value pack = rootNode.unit.\ipackage;
            if(!p.nameAsString.empty
                    && p != pack
                    && p.nameAsString != \iLANGUAGE_MODULE_NAME
                    && (!declaration.classOrInterfaceMember || declaration.staticallyImportable)) {
                if(!isImported(declaration, rootNode)){
                    declarations.add(declaration);
                }
            }
        }
    }

    shared Boolean isImported(Declaration declaration, Tree.CompilationUnit rootNode) {
        for(i in CeylonIterable(rootNode.unit.imports)) {
            if(exists abstraction = nodes.getAbstraction(declaration), i.declaration == abstraction) {
                return true;
            }
        }
        return false;
    }

    shared void importCallableParameterParamTypes(Declaration declaration, JHashSet<Declaration> decs, Tree.CompilationUnit cu) {
        if(is Functional declaration){
            Functional fun = declaration;
            JList<ParameterList> pls = fun.parameterLists;
            if(!pls.empty) {
                for(p in CeylonIterable(pls.get(0).parameters)) {
                    FunctionOrValue pm = p.model;
                    importParameterTypes(pm, cu, decs);
                }
            }
        }
    }

    shared void importParameterTypes(Declaration dec, Tree.CompilationUnit cu, JHashSet<Declaration> decs) {
        if(is Function dec){
            for(ppl in CeylonIterable(dec.parameterLists)) {
                for(pp in CeylonIterable(ppl.parameters)){
                    importSignatureTypes(pp.model, cu, decs);
                }
            }
        }
    }
}
