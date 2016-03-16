import ceylon.collection {
    ArrayList,
    MutableList
}

import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
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
    nodes,
    FindContainerVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    TypedDeclaration,
    ModelUtil,
    Scope,
    Type,
    TypeDeclaration,
    Value,
    UnionType
}

import java.util {
    HashSet,
    JArrayList=ArrayList
}

import org.antlr.runtime {
    CommonToken,
    Token
}


shared interface ExtractFunctionRefactoring<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange, IRegion=DefaultRegion>
        satisfies ExtractInferrableTypedRefactoring<TextChange>
        & NewNameRefactoring
        & DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
        & ExtractLinkedModeEnabled<IRegion>
        given InsertEdit satisfies TextEdit {

    shared formal ImportProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange> importProposals;
    
    value indents => importProposals.indents;
    
    shared formal Node? result;
    shared formal TypedDeclaration? resultDeclaration;
    shared formal List<Tree.Statement> statements;
    shared formal variable Type? returnType;
    shared formal Tree.Declaration? target;
    shared formal List<Tree.Return> returns;
    shared formal Tree.Body? body;
    shared formal actual variable Boolean canBeInferred;
    
    shared class CheckStatementsVisitor(Tree.Body scope, 
        Collection<Tree.Statement> statements) 
            extends Visitor() {
        
        variable shared String? problem = null;
        shared actual void visit(Tree.Body that) {
            if (that==scope) {
                super.visit(that);
            }
        }
        
        function notResult(Node that) 
                => if (exists node = result) 
                then that!=node else true;
        
        function notResultRef(Declaration d) 
                => if (exists rd = resultDeclaration) 
                then rd!=d else true;
        
        shared actual void visit(Tree.Declaration that) {
            super.visit(that);
            if (notResult(that)) {
                value d = that.declarationModel;
                if (d.shared) {
                    problem = "a shared declaration";
                }
                else if (hasOuterRefs(d, scope, statements)) {
                    problem = "a declaration used elsewhere";
                }
            }
        }
        
        shared actual void visit(Tree.SpecifierStatement that) {
            super.visit(that);
            if (notResult(that)) {
                if (is Tree.MemberOrTypeExpression term 
                    = that.baseMemberExpression) {
                    if (exists d = term.declaration, 
                        notResultRef(d), 
                        hasOuterRefs(d, scope, statements)) {
                        problem = "a specification statement for a declaration used or defined elsewhere";
                    }
                }
            }
        }
        
        shared actual void visit(Tree.AssignmentOp that) {
            super.visit(that);
            if (notResult(that)) {
                if (is Tree.MemberOrTypeExpression term = that.leftTerm) {
                    if (exists d = term.declaration,
                        notResultRef(d), 
                        hasOuterRefs(d, scope, statements)) {
                        problem = "an assignment to a declaration used or defined elsewhere";
                    }
                }
            }
        }
        
        shared actual void visit(Tree.Directive that) {
            super.visit(that);
            problem = "a directive statement";
        }
    }

    Boolean containsConstructor(Collection<Tree.Statement> statements) {
        for (statement in statements) {
            if (is Tree.Constructor statement) {
                return true;
            }
        }
        else {
            return false;
        }
    }
    
    shared actual void build(TextChange tfc) {
        if (exists data = editorData) {
            value node = data.node;
            if (is Tree.Term node) {
                extractExpressionInFile(tfc, node);
            } else if (is Tree.Body|Tree.Statement node) {
                extractStatementsInFile(tfc, node);
            }
        }
    }
    
    void extractExpressionInFile(TextChange tfc, Tree.Term term) {
        initMultiEditChange(tfc);
        value doc = getDocumentForChange(tfc);
        value unit = term.unit;
        assert (exists editorData = this.editorData);
        value tokens = editorData.tokens;
        value rootNode = editorData.rootNode;
        
        value start = term.startIndex.longValue();
        value length = term.distance.longValue();
        value unparened = unparenthesize(term);
        variable String body;
        
        if (is Tree.FunctionArgument unparened) {
            value fa = unparened;
            returnType = fa.type.typeModel;
            if (exists block = fa.block) {
                body = nodes.text(block, tokens);
            }
            else if (exists expression = fa.expression) {
                body = "=> " + nodes.text(expression, tokens) + ";";
            }
            else {
                body = "=>;";
            }
        }
        else {
            value t = term.typeModel;
            returnType = unit.denotableType(t);
            body = "=> " + nodes.text(unparened, tokens) + ";";
        }
        
        Tree.Declaration decNode;
        if (exists target = this.target) {
            decNode = target;
        }
        else {
            value fsv = FindContainerVisitor(term);
            rootNode.visit(fsv);
            if (exists dec = fsv.declaration) {
                if (is Tree.AttributeDeclaration dec) {
                    if (exists container 
                        = nodes.getContainer(rootNode, dec.declarationModel)) {
                        decNode = container;
                    }
                    else {
                        decNode = dec;
                    }
                }
                else {
                    decNode = dec;
                }
            }
            else {
                return;
            }
        }
        
        value dec = decNode.declarationModel;
        value flrv = FindLocalReferencesVisitor(term.scope, dec.container);
        term.visit(flrv);
        value localRefs = flrv.localReferences;
        value localTypes = ArrayList<TypeDeclaration>();
        for (bme in localRefs) {
            value t = unit.denotableType(bme.typeModel);
            addLocalType(dec, t, localTypes, ArrayList<Type>());
        }
        
        value params = StringBuilder();
        value args = StringBuilder();
        if (!localRefs.empty) {
            variable Boolean first = true;
            for (bme in localRefs) {
                if (first) {
                    first = false;
                }
                else {
                    params.append(", ");
                    args.append(", ");
                }
                
                if (is TypedDeclaration pdec = bme.declaration, 
                    pdec.dynamicallyTyped) {
                    params.append("dynamic");
                }
                else {
                    value t = unit.denotableType(bme.typeModel);
                    params.append(t.asSourceCodeString(unit));
                }
                
                value name = bme.identifier.text;
                params.append(" ").append(name);
                args.append(name);
            }
        }
        
        value indent = indents.getDefaultLineDelimiter(doc) + indents.getIndent(decNode, doc);
        value extraIndent = indent + indents.defaultIndent;
        value typeParams = StringBuilder();
        value constraints = StringBuilder();
        if (!localTypes.empty) {
            typeParams.append("<");
            variable Boolean first = true;
            for (t in localTypes) {
                if (first) {
                    first = false;
                }
                else {
                    typeParams.append(", ");
                }
                
                typeParams.append(t.name);
                if (!t.satisfiedTypes.empty) {
                    constraints.append(extraIndent)
                               .append(indents.defaultIndent)
                               .append("given ")
                               .append(t.name)
                               .append(" satisfies ");
                    variable Boolean firstConstraint = true;
                    for (pt in t.satisfiedTypes) {
                        if (firstConstraint) {
                            firstConstraint = false;
                        } else {
                            constraints.append("&");
                        }
                        
                        constraints.append(pt.asSourceCodeString(unit));
                    }
                }
            }
            
            typeParams.append(">");
        }
        
        variable Integer il;
        variable String type;
        value rt = this.returnType;
        if (!exists rt) {
            type = "dynamic";
            il = 0;
        }
        else if (rt.unknown) {
            type = "dynamic";
            il = 0;
        }
        else {
            value isVoid = rt.anything;
            if (isVoid) {
                type = "void";
                il = 0;
            }
            else if (explicitType || dec.toplevel) {
                type = rt.asSourceCodeString(unit);
                value decs = HashSet<Declaration>();
                importProposals.importType(decs, returnType, rootNode);
                il = importProposals.applyImports(tfc, decs, rootNode, doc);
            }
            else {
                type = "function";
                il = 0;
                canBeInferred = true;
            }
        }
        
        value text = 
                type + " " + newName + 
                typeParams.string + 
                "(" + params.string + ")" + 
                constraints.string + " " + 
                body + 
                indent + indent;
        variable String invocation;
        variable Integer refStart;
        if (is Tree.FunctionArgument unparened) {
            value fa = unparened;
            value cpl = fa.parameterLists.get(0);
            if (cpl.parameters.size() == localRefs.size) {
                invocation = newName;
                refStart = start;
            }
            else {
                value header = nodes.text(cpl, tokens) + " => ";
                invocation = header + newName + "(" + args.string + ")";
                refStart = start + header.size;
            }
        }
        else {
            invocation = newName + "(" + args.string + ")";
            refStart = start;
        }
        
        value decStart = decNode.startIndex.longValue();
        addEditToChange(tfc, newInsertEdit(decStart, text));
        addEditToChange(tfc, newReplaceEdit(start, length, invocation));
        typeRegion = newRegion(decStart + il, type.size);
        value nl = newName.size;
        decRegion = newRegion(decStart + il + type.size + 1, nl);
        refRegion = newRegion(refStart + il + text.size, nl);
    }
    
    void extractStatementsInFile(TextChange tfc, Tree.Body|Tree.Statement node) {
        assert (exists body = this.body);
        assert (exists editorData = this.editorData);
        initMultiEditChange(tfc);
        value doc = getDocumentForChange(tfc);
        value unit = body.unit;
        value tokens = editorData.tokens;
        value rootNode = editorData.rootNode;        
        
        assert (nonempty ss = statements.sequence());
        value start = ss.first.startIndex.longValue();
        variable value length = ss.last.endIndex.longValue() - start;
        variable Tree.Declaration decNode;
        if (exists target = this.target) {
            decNode = target;
        }
        else {
            value fsv = FindContainerVisitor(body);
            rootNode.visit(fsv);
            if (exists fsvd = fsv.declaration) {
                decNode = fsvd;
            }
            else {
                return;
            }
        }
        
        value dec = decNode.declarationModel;
        value flrv = FindLocalReferencesVisitor(body.scope, dec.container);
        for (s in statements) {
            s.visit(flrv);
        }
        
        value localTypes = ArrayList<TypeDeclaration>();
        value localReferences = flrv.localReferences;
        for (bme in localReferences) {
            value t = unit.denotableType(bme.typeModel);
            addLocalType(dec, t, localTypes, ArrayList<Type>());
        }
        
        for (s in statements) {
            object extends Visitor() {
                shared actual void visit(Tree.TypeArgumentList that) {
                    for (pt in that.typeModels) {
                        value t = unit.denotableType(pt);
                        addLocalType(dec, t, localTypes, ArrayList<Type>());
                    }
                }
            }.visit(s);
        }
        
        value movingDecs = HashSet<Declaration>();
        for (s in statements) {
            if (is Tree.Declaration s) {
                value d = s;
                movingDecs.add(d.declarationModel);
            }
        }
        
        variable String params = "";
        variable String args = "";
        value done = HashSet<Declaration>(movingDecs);
        variable Boolean notEmpty = false;
        for (bme in localReferences) {
            value bmed = bme.declaration;
            if (if (exists rdec = resultDeclaration) then bmed!=rdec || rdec.variable else true) {
                if (done.add(bmed)) {
                    if (is Value bmed, bmed.variable) {
                        params += "variable ";
                    }
                    
                    value bmet = bme.typeModel;
                    if (is TypedDeclaration bmed) {
                        value td = bmed;
                        if (td.dynamicallyTyped) {
                            params += "dynamic";
                        }
                        else {
                            value t = unit.denotableType(bmet);
                            params += t.asSourceCodeString(unit);
                        }
                    }
                    else {
                        value t = unit.denotableType(bmet);
                        params += t.asSourceCodeString(unit);
                    }
                    
                    value id = bme.identifier;
                    params += " "+id.text+", ";
                    args += id.text+", ";
                    notEmpty = true;
                }
            }
        }
        
        if (notEmpty) {
            params = params.initial(params.size-2);
            args = args.initial(args.size-2);
        }
        
        value indent = indents.getDefaultLineDelimiter(doc) + indents.getIndent(decNode, doc);
        value extraIndent = indent + indents.defaultIndent;
        variable String typeParams = "";
        variable String constraints = "";
        if (!localTypes.empty) {
            for (t in localTypes) {
                typeParams += t.name + ", ";
                value sts = t.satisfiedTypes;
                if (!sts.empty) {
                    constraints += extraIndent+indents.defaultIndent+"given "+t.name+" satisfies ";
                    for (pt in sts) {
                        constraints += pt.asSourceCodeString(unit) + "&";
                    }
                    constraints = constraints.initial(constraints.size-1);
                }
            }
            typeParams = "<" + typeParams.initial(typeParams.size-2) + ">";
        }
        
        if (exists rdec = resultDeclaration) {
            returnType = unit.denotableType(rdec.type);
        }
        else if (!returns.empty) {
            value ut = UnionType(unit);
            value list = JArrayList<Type>();
            for (r in returns) {
                if (exists e = r.expression) {
                    value t = e.typeModel;
                    ModelUtil.addToUnion(list, t);
                }
            }
            
            ut.caseTypes = list;
            returnType = ut.type;
        }
        else {
            returnType = null;
        }
        
        String typeOrKeyword;
        Integer il;
        if (resultDeclaration exists || !returns.empty) {
            value returnType = this.returnType;
            if (!exists returnType) {
                typeOrKeyword = "dynamic";
                il = 0;
            }
            else if (returnType.unknown) {
                typeOrKeyword = "dynamic";
                il = 0;
            }
            else if (explicitType || dec.toplevel) {
                typeOrKeyword = returnType.asSourceCodeString(unit);
                value already = HashSet<Declaration>();
                importProposals.importType(already, returnType, rootNode);
                il = importProposals.applyImports(tfc, already, rootNode, doc);
            }
            else {
                typeOrKeyword = "function";
                il = 0;
            }
        }
        else {
            typeOrKeyword = "void";
            il = 0;
        }
        
        variable String content =
                typeOrKeyword + " " + newName + typeParams + 
                "(" + params + ")" + 
                constraints + " {";
        if (exists rdec = resultDeclaration, !result is Tree.Declaration, !rdec.variable) {
            content += extraIndent + rdec.type.asSourceCodeString(unit) + " " + rdec.name + ";";
        }
        
        value last = ss.last;
        for (s in statements) {
            content += extraIndent + nodes.text(s, tokens);
            variable Integer i = s.endToken.tokenIndex;
            variable CommonToken tok;
            while ((tok = tokens.get(++i)).channel == Token.\iHIDDEN_CHANNEL) {
                value text = tok.text;
                if (tok.type == CeylonLexer.\iLINE_COMMENT) {
                    content += " " + text.initial(text.size-1);
                    if (s == last) {
                        length += text.size;
                    }
                }
                
                if (tok.type == CeylonLexer.\iMULTI_COMMENT) {
                    content += " " + text;
                    if (s == last) {
                        length += text.size + 1;
                    }
                }
            }
        }
        
        if (exists rdec = resultDeclaration) {
            content += extraIndent + "return " + rdec.name + ";";
        }
        
        content += indent + "}" + indent + indent;
        String ctx;
        if (exists rdec = resultDeclaration) {
            String modifs;
            if (result is Tree.AttributeDeclaration) {
                if (rdec.shared, exists type = returnType) {
                    modifs = "shared " + type.asSourceCodeString(unit) + " ";
                }
                else {
                    modifs = "value ";
                }
            }
            else {
                modifs = "";
            }
            ctx = modifs + rdec.name + "=";
        } 
        else if (!returns.empty) {
            ctx = "return " + newName + "(" + args + ");";
        }
        else {
            ctx = "";
        }
        String invocation = ctx + newName + "(" + args + ");";
        
        value space = content.firstOccurrence(' ') else -1;
        value eq = invocation.firstOccurrence('=') else -1;
        value decStart = decNode.startIndex.longValue();
        addEditToChange(tfc, newInsertEdit(decStart, content));
        addEditToChange(tfc, newReplaceEdit(start, length, invocation));
        typeRegion = newRegion(decStart + il, space);
        decRegion = newRegion(decStart + il + space + 1, newName.size);
        refRegion = newRegion(start + content.size + il + eq + 1, newName.size);
    }
    
    void addLocalType(Declaration dec, Type type, 
        MutableList<TypeDeclaration> localTypes, 
        MutableList<Type> visited) {
        if (visited.contains(type)) {
            return;
        }
        else {
            visited.add(type);
        }
        
        value td = type.declaration;
        if (td.container == dec) {
            variable Boolean found = false;
            for (typeDeclaration in localTypes) {
                if (typeDeclaration == td) {
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                localTypes.add(td);
            }
        }
        
        for (pt in type.satisfiedTypes) {
            addLocalType(dec, pt, localTypes, visited);
        }
        
        for (pt in type.typeArgumentList) {
            addLocalType(dec, pt, localTypes, visited);
        }
    }

    
    shared actual Boolean forceWizardMode() {
        if (exists data = editorData,
            exists node = data.node,
            exists scope = node.scope) {
            if (is Tree.Body node) {
                for (s in statements) {
                    value v = CheckStatementsVisitor(node, statements);
                    s.visit(v);
                    if (v.problem exists) {
                        return true;
                    }
                }
            }
            else if (is Tree.Term node) {
                variable value problem = false;
                node.visit(object extends Visitor() {
                    shared actual void visit(Tree.Body that) {}
                    shared actual void visit(Tree.AssignmentOp that) {
                        problem = true;
                        super.visit(that);
                    }
                });
                if (problem) {
                    return true;
                }
            }
            return node.scope.getMemberOrParameter(node.unit, newName, null, false) exists;
        }
        else {
            return false;
        }
    }
    
    shared actual String initialNewName() { 
        if (exists rdec = resultDeclaration) {
            return rdec.name;
        }
        else if (exists node = editorData?.node) {
            return let (newName = nodes.nameProposals(node, false, editorData?.rootNode).get(0).string)
                if ("it" == newName) then "do" else newName;
        }
        else {
            return "";
        }
    }
    
    editable => true;
    
    enabled => if (exists data = editorData,
                   exists sourceFile = data.sourceVirtualFile,
                   editable &&
                   sourceFile.name != "module.ceylon" &&
                   sourceFile.name != "package.ceylon" &&
                   (data.node is Tree.Term || 
                    data.node is Tree.Body|Tree.Statement &&
                        !statements.empty &&
                        !containsConstructor(statements)))
               then true
               else false;
    
    nameProposals
            => nodes.nameProposals(editorData?.node, false, editorData?.rootNode);
    
    name => "Extract Function";
}

shared class FindBodyVisitor(Node node) extends Visitor() {
    shared variable Tree.Body? body = null;
    shared actual void visit(Tree.Body that) {
        super.visit(that);
        if (that.statements.contains(node)) {
            body = that;
        }
    }
}

shared class FindResultVisitor(Tree.Body scope, 
    Collection<Tree.Statement> statements) 
        extends Visitor() {
    
    variable shared Node? result = null;
    variable shared TypedDeclaration? resultDeclaration = null;
    
    function isDefinedLocally(Declaration dec) 
            => !ModelUtil.contains(dec.scope, scope.scope.container);
    
    shared actual void visit(Tree.Body that) {
        if (that is Tree.Block) {
            super.visit(that);
        }
    }
    
    shared actual void visit(Tree.AttributeDeclaration that) {
        super.visit(that);
        value dec = that.declarationModel;
        if (hasOuterRefs(dec, scope, statements)) {
            result = that;
            resultDeclaration = dec;
        }
    }
    
    shared actual void visit(Tree.AssignmentOp that) {
        super.visit(that);
        if (is Tree.StaticMemberOrTypeExpression leftTerm 
                = that.leftTerm) {
            if (is TypedDeclaration dec = leftTerm.declaration,
                hasOuterRefs(dec, scope, statements), 
                isDefinedLocally(dec)) {
                result = that;
                resultDeclaration = dec;
            }
        }
    }
    
    shared actual void visit(Tree.SpecifierStatement that) {
        super.visit(that);
        if (is Tree.StaticMemberOrTypeExpression term 
                = that.baseMemberExpression) {
            if (is TypedDeclaration dec = term.declaration,
                hasOuterRefs(dec, scope, statements), 
                isDefinedLocally(dec)) {
                result = that;
                resultDeclaration = dec;
            }
        }
    }
    
}

Boolean hasOuterRefs(Declaration d, Tree.Body? scope, 
    Collection<Tree.Statement> statements) {
    if (!exists scope) {
        return false;
    }
    
    variable Integer refs = 0;
    for (s in scope.statements) {
        if (!statements.contains(s)) {
            s.visit(object extends Visitor() {
                shared actual void visit(Tree.MemberOrTypeExpression that) {
                    super.visit(that);
                    if (exists dec = that.declaration, 
                        d==dec) {
                        refs++;
                    }
                }
                shared actual void visit(Tree.Declaration that) {
                    super.visit(that);
                    if (exists dec = that.declarationModel, 
                        d==dec) {
                        refs++;
                    }
                }
                shared actual void visit(Tree.Type that) {
                    super.visit(that);
                    if (exists type = that.typeModel, 
                        type.classOrInterface) {
                        if (exists td = type.declaration, 
                            d==td) {
                            refs++;
                        }
                    }
                }
            });
        }
    }
    return refs > 0;
}

shared class FindReturnsVisitor(MutableList<Tree.Return> returns) 
        extends Visitor() {
    shared actual void visit(Tree.Declaration that) {}
    shared actual void visit(Tree.Return that) {
        super.visit(that);
        if (that.expression exists) {
            returns.add(that);
        }
    }
}

class FindLocalReferencesVisitor(Scope scope, Scope targetScope) 
        extends Visitor() {
    
    value results = ArrayList<Tree.BaseMemberExpression>();
    
    shared List<Tree.BaseMemberExpression> localReferences => results;
    
    shared actual void visit(Tree.BaseMemberExpression that) {
        super.visit(that);
        value currentDec = that.declaration;
        for (bme in results) {
            if (exists dec = bme.declaration) {
                if (dec==currentDec) {
                    return;
                }
                if (is TypedDeclaration currentDec, 
                    exists od = currentDec.originalDeclaration, 
                    od==dec) {
                    return;
                }
            }
        }
        
        if (currentDec.isDefinedInScope(scope), 
            !currentDec.isDefinedInScope(targetScope)) {
            results.add(that);
        }
    }
}
