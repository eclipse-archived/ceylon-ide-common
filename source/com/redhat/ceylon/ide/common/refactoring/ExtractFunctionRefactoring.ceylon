import ceylon.collection {
    ArrayList,
    MutableList,
    HashMap,
    HashSet
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
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
    UnionType,
    Unit,
    IntersectionType
}

import java.util {
    JList=List,
    JHashSet=HashSet,
    JArrayList=ArrayList,
    JSet=Set
}

import org.antlr.runtime {
    CommonToken,
    Token
}

shared interface ExtractFunctionRefactoring<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange, Change, IRegion=DefaultRegion>
        satisfies ExtractInferrableTypedRefactoring<TextChange>
        & NewNameRefactoring
        & DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
        & ExtractLinkedModeEnabled<IRegion>
        given InsertEdit satisfies TextEdit {

    shared formal ImportProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange> importProposals;
    value indents => importProposals.indents;
    
    initialNewName => nameProposals[0];
    
    shared formal List<Tree.Statement> statements;
    shared formal Tree.Declaration? target;
    shared formal List<Node->TypedDeclaration> results;
    shared formal List<Tree.Return> returns;
    shared formal Tree.Body? body;
    shared formal variable actual Type? type;
    shared formal actual variable Boolean canBeInferred;
    
    shared formal JList<IRegion> dupeRegions;    
    
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
                => !that in results.map(Entry.key);
        
        function notResultRef(Declaration d) 
                => !d in results.map(Entry.item);
        
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
    
    shared actual void build(TextChange tfc) {
        value node = editorData.node;
        if (is Tree.Term node) {
            extractExpression(tfc, node);
        }
        else if (is Tree.Body|Tree.Statement node) {
            extractStatements(tfc, node);
        }
    }
    
    function typeParameters(
        ArrayList<TypeDeclaration> localTypes, 
        String extraIndent, Unit unit, 
        JSet<Declaration> imports) {
        value typeParams = StringBuilder();
        value constraints = StringBuilder();
        if (!localTypes.empty) {
            typeParams.appendCharacter('<');
            for (t in localTypes) {
                if (typeParams.size>1) {
                    typeParams.append(", ");
                }
                typeParams.append(t.name);
                value sts = t.satisfiedTypes;
                if (!sts.empty) {
                    constraints
                            .append(extraIndent)
                            .append("given ") 
                            .append(t.name)
                            .append(" satisfies ");
                    for (boundType in sts) {
                        importProposals.importType(imports, boundType, rootNode);
                        value bound = boundType.asSourceCodeString(unit);
                        constraints
                                .append(bound)
                                .appendCharacter('&');
                    }
                    constraints.deleteTerminal(1);
                }
            }
            typeParams.appendCharacter('>');
        }
        return [typeParams, constraints];
    }
    
    function asArgList(
        List<Tree.Term> localRefs, 
        List<Tree.Term> localThisRefs, 
        JList<CommonToken> tokens) {
        value args 
                = localThisRefs.take(1).chain(localRefs)
                    .map((term) => nodes.text(tokens, term));
        return ", ".join(args);
    }
    
    function fakeToken(Tree.This tr) {
        value tok = CommonToken(CeylonLexer.\iLIDENTIFIER, "that");
        tok.startIndex = tr.startIndex.intValue();
        tok.stopIndex = tr.stopIndex.intValue();
        tok.tokenIndex = tr.token.tokenIndex;
        return tok;
    }
    
    shared void extractExpression(TextChange tfc, Tree.Term term, 
            Change? change = null) {
        initMultiEditChange(tfc);
        value doc = getDocumentForChange(tfc);
        value unit = term.unit;
        value tokens = editorData.tokens;
        value rootNode = editorData.rootNode;
        
        value start = term.startIndex.intValue();
        value length = term.distance.intValue();
        value core = unparenthesize(term);
        
        value decNode = getTargetNode(term, target, rootNode);
        if (!exists decNode) {
            return;
        }
        value dec = decNode.declarationModel;
        
        value flrv = FindLocalReferencesVisitor {
            scope = ModelUtil.getRealScope(term.scope);
            targetScope = dec.container;
        };
        term.visit(flrv);
        value localRefs = flrv.localReferences;
        value localThisRefs = flrv.localThisReferences;
        value localTypes = ArrayList<TypeDeclaration>();
        for (bme in localRefs) {
            addLocalType {
                scope = ModelUtil.getRealScope(term.scope);
                targetScope = dec.container;
                type = unit.denotableType(bme.typeModel);
                localTypes = localTypes;
                visited = ArrayList<Type>();
            };
        }
        
        value imports = JHashSet<Declaration>();
        
        value params = StringBuilder();
        for (tr in localThisRefs) {
            params.append(tr.typeModel.asSourceCodeString(unit))
                .append(" that");
            break;
        }
        for (bme in localRefs) {
            if (!params.empty) {
                params.append(", ");
            }
            
            if (is TypedDeclaration pdec = bme.declaration, 
                pdec.dynamicallyTyped) {
                params.append("dynamic");
            }
            else {
                value paramType = unit.denotableType(bme.typeModel);
                importProposals.importType(imports, paramType, rootNode);
                params.append(paramType.asSourceCodeString(unit));
            }
            
            value name = bme.identifier.text;
            params.append(" ").append(name);
        }
        value argList = asArgList {
            localRefs = localRefs;
            localThisRefs = localThisRefs;
            tokens = tokens;
        };
        
        value indent = 
                indents.getDefaultLineDelimiter(doc) + 
                indents.getIndent(decNode, doc);
        value extraIndent = 
                indent + 
                indents.defaultIndent + 
                indents.defaultIndent;
        value [typeParams, constraints]
                = typeParameters {
                    localTypes = localTypes;
                    extraIndent = extraIndent;
                    unit = unit;
                    imports = imports;
                };
        
        value specifier = extraIndent + "=> ";
        value fixedTokens = JArrayList(tokens);
        for (tr in localThisRefs) {
            fixedTokens.set(tokens.indexOf(tr.token), 
                fakeToken(tr));
        }
        String body;
        if (is Tree.FunctionArgument core) {
            //special case for anonymous functions!
            if (!type exists) {
                type = unit.denotableType(core.type.typeModel);
            }
            if (exists block = core.block) {
                body = nodes.text(fixedTokens, block);
            }
            else if (exists expression = core.expression) {
                body = specifier + nodes.text(fixedTokens, expression) + ";";
            }
            else {
                body = specifier + ";";
            }
        }
        else {
            if (!type exists) {
                type = unit.denotableType(core.typeModel);
            }
            body = specifier + nodes.text(fixedTokens, core) + ";";
        }
        
        String typeOrKeyword;
        if (exists returnType = this.type, 
            !returnType.unknown) {
            value voidModifier = returnType.anything;
            if (voidModifier) {
                typeOrKeyword = "void";
            }
            else if (explicitType || dec.toplevel) {
                typeOrKeyword = returnType.asSourceCodeString(unit);
                importProposals.importType(imports, returnType, rootNode);
            }
            else {
                typeOrKeyword = "function";
                canBeInferred = true;
            }
        }
        else {
            typeOrKeyword = "dynamic";
        }
        
        value definition = 
                typeOrKeyword + " " + newName + 
                typeParams.string + 
                "(" + params.string + ")" + 
                constraints.string + " " + 
                body + 
                indent + indent;
        
        String invocation;
        Integer refStart;
        if (is Tree.FunctionArgument core) {
            value cpl = core.parameterLists.get(0);
            if (cpl.parameters.size() == localRefs.size) {
                invocation = newName;
                refStart = start;
            }
            else {
                value header = nodes.text(tokens, cpl) + " => ";
                invocation = header + newName + "(" + argList.string + ")";
                refStart = start + header.size;
            }
        }
        else {
            invocation = newName + "(" + argList.string + ")";
            refStart = start;
        }
        
        value shift 
                = importProposals.applyImports {
            change = tfc;
            declarations = imports;
            rootNode = rootNode;
            doc = doc;
        };
        
        value decStart = decNode.startIndex.intValue();
        addEditToChange(tfc, newInsertEdit(decStart, definition));
        addEditToChange(tfc, newReplaceEdit(start, length, invocation));
        typeRegion = newRegion(decStart + shift, typeOrKeyword.size);
        decRegion = newRegion(decStart + shift + typeOrKeyword.size + 1, newName.size);
        refRegion = newRegion(refStart + shift + definition.size, newName.size);
        
        object extends Visitor() {
            variable value backshift = length - invocation.size;
            shared actual void visit(Tree.Term t) {
                value tstart = t.startIndex?.intValue();
                value tlength = t.distance?.intValue();
                value args = ArrayList<Tree.Term>();
                if (exists tstart, exists tlength,
                    ModelUtil.contains(decNode.scope.container, t.scope)
                    && tstart > start + length //TODO: make it work for earlier expressions in the file
                    && t!=term 
                    && !different {
                        term = term;
                        expression = t;
                        localRefs = localRefs;
                        arguments = args;
                    }) {
                    value invocation = 
                            newName + 
                            "(" + 
                            asArgList(args, localThisRefs, tokens) + 
                            ")";
                    addEditToChange(tfc, 
                        newReplaceEdit {
                            start = tstart;
                            length = tlength;
                            text = invocation;
                        });
                    dupeRegions.add(newRegion {
                        start = tstart + shift + definition.size - backshift;
                        length = newName.size;
                    });
                    backshift += tlength - invocation.size;
                }
                else {
                    super.visit(t);
                }
            }
        }.visit(rootNode);
        
        if (exists change) {
            for (pu in getAllUnits()) {
                if (pu.unit.\ipackage==unit.\ipackage && pu.unit!=unit) {
                    value tc = newFileChange(pu);
                    initMultiEditChange(tc);
                    variable value found = false;
                    object extends Visitor() {
                        shared actual void visit(Tree.Term t) {
                            value tstart = t.startIndex?.intValue();
                            value tlength = t.distance?.intValue();
                            value args = ArrayList<Tree.Term>();
                            if (exists tstart, exists tlength,
                                !different {
                                    term = term;
                                    expression = t;
                                    localRefs = localRefs;
                                    arguments = args;
                                }) {
                                value invocation = 
                                        newName + 
                                        "(" + 
                                        asArgList(args, localThisRefs, pu.tokens) +
                                        ")";
                                addEditToChange(tc, 
                                    newReplaceEdit {
                                        start = tstart;
                                        length = tlength;
                                        text = invocation;
                                    });
                                found = true;
                            }
                            else {
                                super.visit(t);
                            }
                        }
                    }.visit(pu.compilationUnit);
                    if (found) {
                        addChangeToChange(change, tc);
                    }
                }
            }
        }
    }
    
    shared formal TextChange newFileChange(PhasedUnit pu);
    shared formal void addChangeToChange(Change change, TextChange tc);
    
    function targetDeclaration(Tree.Body body, 
        Tree.CompilationUnit rootNode) {
        if (exists target = this.target) {
            return target;
        }
        else {
            value fsv = FindContainerVisitor(body);
            rootNode.visit(fsv);
            return fsv.declaration;
        }
    }
    
    function resultModifiers(Node result, 
        TypedDeclaration rdec, 
        Unit unit, 
        JSet<Declaration> imports) {
        if (result is Tree.AttributeDeclaration) {
            if (rdec.shared, exists type = rdec.type) {
                importProposals.importType(imports, type, rootNode);
                return "shared " + type.asSourceCodeString(unit) + " ";
            }
            else {
                return "value ";
            }
        }
        else {
            return "";
        }
    }
    
    function appendComments([Tree.Statement+] ss, 
        StringBuilder definition, 
        String bodyIndent, 
        JList<CommonToken> tokens) {
        value end = ss.last.endIndex.intValue();
        variable value endOfComments = end;
        for (s in statements) {
            definition
                    .append(bodyIndent)
                    .append(nodes.text(tokens, s));
            variable Integer i = s.endToken.tokenIndex;
            variable CommonToken tok;
            while ((tok = tokens.get(++i)).channel == Token.\iHIDDEN_CHANNEL) {
                value text = tok.text;
                if (tok.type == CeylonLexer.\iLINE_COMMENT) {
                    definition
                            .append(" ")
                            .append(text.trimmed);
                    if (s == ss.last) {
                        endOfComments = tok.stopIndex + 1;
                    }
                }
                
                if (tok.type == CeylonLexer.\iMULTI_COMMENT) {
                    definition
                            .append(" ")
                            .append(text);
                    if (s == ss.last) {
                        endOfComments = tok.stopIndex + 1;
                    }
                }
            }
        }
        return endOfComments;
    }
    
    void extractStatements(TextChange tfc, Tree.Body|Tree.Statement node) {
        assert (exists body = this.body);
        initMultiEditChange(tfc);
        value doc = getDocumentForChange(tfc);
        value unit = body.unit;
        value tokens = editorData.tokens;
        value rootNode = editorData.rootNode;        
        
        assert (exists decNode = targetDeclaration(body, rootNode));
        assert (nonempty ss = statements.sequence());
        
        value dec = decNode.declarationModel;
        value flrv = FindLocalReferencesVisitor {
            scope = body.scope;
            targetScope = dec.container;
        };
        for (s in statements) {
            s.visit(flrv);
        }
        
        value localReferences = flrv.localReferences;
        value localThisReferences = flrv.localThisReferences;
        value localTypes = ArrayList<TypeDeclaration>();
        value visited = ArrayList<Type>();
        for (bme in localReferences) {
            addLocalType {
                scope = body.scope;
                targetScope = dec.container;
                type = unit.denotableType(bme.typeModel);
                localTypes = localTypes;
                visited = visited;
            };
        }
        
        for (s in statements) {
            object extends Visitor() {
                shared actual void visit(Tree.TypeArgumentList that) {
                    for (pt in that.typeModels) {
                        addLocalType {
                            scope = body.scope;
                            targetScope = dec.container;
                            type = unit.denotableType(pt);
                            localTypes = localTypes;
                            visited = visited;
                        };
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
        
        value imports = JHashSet<Declaration>();
        
        value params = StringBuilder();
        value args = StringBuilder();
        value done = HashSet<Declaration>();
        done.addAll(movingDecs);
        for (tr in localThisReferences) {
            if (!params.empty) {
                params.append(", ");
                args.append(", ");
            }
            params.append(tr.typeModel.asSourceCodeString(unit))
                    .append(" that");
            args.append(tr.text);
            break;
        }
        for (bme in localReferences) {
            value bmed = bme.declaration;
            value variable = 
                    if (is Value bmed) 
                    then bmed.variable //TODO: wrong condition, check if initialized! 
                    else false;
            value result = bmed in results.map(Entry.item);
            //ignore it if it is a result of the function 
            //and is not a variable
            if (variable || !result) {
                if (done.add(bmed)) {
                    if (!params.empty) {
                        params.append(", ");
                        args.append(", ");
                    }
                    
                    if (is Value bmed, bmed.variable) {
                        params.append("variable ");
                    }
                    
                    if (is TypedDeclaration bmed, 
                        bmed.dynamicallyTyped) {
                        params.append("dynamic");
                    }
                    else {
                        value paramType = unit.denotableType(bme.typeModel);
                        importProposals.importType(imports, paramType, rootNode);
                        params.append(paramType.asSourceCodeString(unit));
                    }
                    
                    value id = bme.identifier;
                    params.append(" ").append(id.text);
                    args.append(id.text);
                }
            }
        }
        
        value indent = 
                indents.getDefaultLineDelimiter(doc) + 
                indents.getIndent(decNode, doc);
        value extraIndent = 
                indent + 
                indents.defaultIndent + 
                indents.defaultIndent;
        value [typeParams, constraints]
                = typeParameters {
                    localTypes = localTypes;
                    extraIndent = extraIndent;
                    unit = unit;
                    imports = imports;
                };
        
        if (results.size==1) {
            assert (exists _ -> rdec = results.first);
            if (!type exists) {
                type = unit.denotableType(rdec.type);
            }
        }
        else if (!results.empty) {
            value types = JArrayList<Type>();
            for (_ -> rdec in results) {
                types.add(rdec.type);
            }
            if (!type exists) {
                type = unit.getTupleType(types, null, -1);
            }
        }
        else if (!returns.empty) {
            value ut = UnionType(unit);
            value list = JArrayList<Type>();
            for (ret in returns) {
                if (exists e = ret.expression) {
                    ModelUtil.addToUnion(list, e.typeModel);
                }
            }
            ut.caseTypes = list;
            if (!type exists) {
                type = ut.type;
            }
        }
        else {
            type = null;
        }
        
        String typeOrKeyword;
        if (returns.empty && results.empty) {
            //we're not assigning the result to anything,
            //so make a void function
            typeOrKeyword = "void";
        }
        else if (exists returnType = this.type,
                !returnType.unknown) {
            //we need to return a value
            if (explicitType || dec.toplevel) {
                typeOrKeyword = returnType.asSourceCodeString(unit);
                importProposals.importType(imports, returnType, rootNode);
            }
            else {
                typeOrKeyword = "function";
            }
        }
        else {
            typeOrKeyword = "dynamic";
        }
        
        value bodyIndent = indent + indents.defaultIndent;
        value definition = StringBuilder();
        definition
                .append(typeOrKeyword)
                .append(" ")
                .append(newName)
                .append(typeParams.string)
                .append("(").append(params.string).append(")")
                .append(constraints.string)
                .append(" {");
        for (result -> rdec in results) { 
            if (!result is Tree.Declaration &&
                !rdec.variable) {  //TODO: wrong condition, check if initialized!
                value resultType = rdec.type;
                importProposals.importType(imports, resultType, rootNode);
                definition
                        .append(bodyIndent)
                        .append(resultType.asSourceCodeString(unit))
                        .append(" ")
                        .append(rdec.name)
                        .append(";");
            }
        }
        
        value fixedTokens = JArrayList(tokens);
        for (tr in localThisReferences) {
            fixedTokens.set(tokens.indexOf(tr.token), 
                fakeToken(tr));
        }
        value start = ss.first.startIndex.intValue();
        value end = appendComments {
            ss = ss;
            definition = definition;
            bodyIndent = bodyIndent;
            tokens = fixedTokens;
        };
        value length = end - start;
        
        if (results.size==1) {
            assert (exists result -> rdec = results.first);
            definition
                    .append(bodyIndent)
                    .append("return ")
                    .append(rdec.name)
                    .append(";");
        }
        else if (!results.empty) {
            definition
                    .append(bodyIndent)
                    .append("return [")
                    .append(", ".join { for (_ -> rdec in results) rdec.name })
                    .append("];");
        }
        
        definition
                .append(indent)
                .append("}")
                .append(indent)
                .append(indent);
        
        value call = newName + "(" + args.string + ");";
        value invocation = StringBuilder();
        if (results.size==1) {
            //we're assigning the result of the extracted 
            //function to something
            assert (exists result -> rdec = results.first);
            invocation
                    .append(resultModifiers {
                        result = result;
                        rdec = rdec;
                        unit = unit;
                        imports = imports;
                    })
                    .append(rdec.name)
                    .append(" = ")
                    .append(call);
        }
        else if (!results.empty) {
            //we're assigning the result tuple of the extracted 
            //function to various things
            if (results.every((e)=>e.key is Tree.AttributeDeclaration && !e.item.shared)) {
                invocation
                        .append("value [")
                        .append(", ".join { for (_ -> rdec in results) rdec.name })
                        .append("] = ")
                        .append(call);
            }
            else {
                invocation
                        .append("value tuple = ")
                        .append(call);
                value ind =
                        indents.getDefaultLineDelimiter(doc) + 
                        indents.getIndent(ss.last, doc);
                variable value i = 0;
                for (result -> rdec in results) {
                    invocation
                            .append(ind)
                            .append(resultModifiers {
                                result = result;
                                rdec = rdec;
                                unit = unit;
                                imports = imports;
                            })
                            .append(rdec.name)
                            .append(" = tuple[")
                            .append(i.string)
                            .append("];");
                    i++;
                }
            }
        } 
        else if (!returns.empty) {
            //we're returning the result of the extracted function
            invocation.append("return ").append(call);
        }
        else {
            //we're just calling the extracted function
            invocation.append(call);
        }
        
        value shift 
                = importProposals.applyImports {
            change = tfc;
            declarations = imports;
            rootNode = rootNode;
            doc = doc;
        };
                
        value decStart = decNode.startIndex.intValue();
        addEditToChange(tfc, newInsertEdit(decStart, definition.string));
        addEditToChange(tfc, newReplaceEdit(start, length, invocation.string));
        typeRegion = newRegion(decStart + shift, typeOrKeyword.size);
        decRegion = newRegion(decStart + shift + typeOrKeyword.size+1, newName.size);
        value callLoc = invocation.string.firstInclusion(call) else 0;
        refRegion = newRegion(start + definition.size + shift + callLoc, newName.size);
    }
    
    void addLocalType(Scope scope, Scope targetScope, Type type, 
        MutableList<TypeDeclaration> localTypes, 
        MutableList<Type> visited) {
        if (!type.unknown, exists typeDec = type.declaration) {
            switch (typeDec)
            case (is UnionType) {
                for (ct in type.caseTypes) {
                    addLocalType {
                        scope = scope;
                        targetScope = targetScope;
                        type = ct;
                        localTypes = localTypes;
                        visited = visited;
                    };
                }
            }
            case (is IntersectionType) {
                for (st in type.satisfiedTypes) {
                    addLocalType {
                        scope = scope;
                        targetScope = targetScope;
                        type = st;
                        localTypes = localTypes;
                        visited = visited;
                    };
                }
            }
            else if (!type in visited) {
                visited.add(type);
                
                if (isLocalReference(typeDec, scope, targetScope) &&
                    !typeDec in localTypes) {
                    localTypes.add(typeDec);
                }
                
                //TODO: what is this for?!
                for (st in type.satisfiedTypes) {
                    addLocalType {
                        scope = scope;
                        targetScope = targetScope;
                        type = st;
                        localTypes = localTypes;
                        visited = visited;
                    };
                }
                
                for (ta in type.typeArgumentList) {
                    addLocalType {
                        scope = scope;
                        targetScope = targetScope;
                        type = ta;
                        localTypes = localTypes;
                        visited = visited;
                    };
                }
            }
        }
    }
    
    shared actual Boolean forceWizardMode {
        value node = editorData.node;

        if (exists scope = node.scope) {
            if (is Tree.Body|Tree.Statement node, 
                exists body = this.body) {
                for (s in statements) {
                    value v = CheckStatementsVisitor(body, statements);
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
            return scope.getMemberOrParameter(node.unit, newName, null, false) exists;
        }
        else {
            return false;
        }
    }
    
    enabled => if (exists sourceFile = editorData.sourceVirtualFile)
               then editable(editorData.rootNode.unit) &&
                   !descriptor(sourceFile) &&
                   (editorData.node is Tree.Term ||
                    editorData.node is Tree.Body|Tree.Statement &&
                        !statements.empty &&
                        !statements.any((statement) 
                            => statement is Tree.Constructor))
               else false;
    
    shared actual [String+] nameProposals {
        value proposals = nodes.nameProposals {
            node = editorData.node;
            rootNode = editorData.rootNode;
        }.collect((n) => n=="it" then "do" else n);
        
        if (!results.empty) {
            value name =
                    "get" + 
                    "And".join { 
                        for (_ -> rdec in results) 
                        rdec.name[0..0].uppercased + 
                                rdec.name[1...] };
            return proposals.withLeading(name);
        }
        else {
            return proposals;
        }
    }
    
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
    
    value resultsList = ArrayList<Node->TypedDeclaration>();
    shared List<Node->TypedDeclaration> results => resultsList;
    
    value possibles = HashMap<TypedDeclaration,Node>();
    value all = HashSet<TypedDeclaration>();
    
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
        if (that.specifierOrInitializerExpression exists) {
            if (hasOuterRefs(dec, scope, statements)) {
                resultsList.add(that->dec);
                all.add(dec);
            }
        }
        possibles.put(dec, that);
    }
    
    //TODO: Tree.AnyMethod!!!!
    
    shared actual void visit(Tree.AssignmentOp that) {
        super.visit(that);
        if (is Tree.StaticMemberOrTypeExpression leftTerm 
                = that.leftTerm, 
            is TypedDeclaration dec = leftTerm.declaration,
            hasOuterRefs(dec, scope, statements) 
                    && isDefinedLocally(dec)) {
            resultsList.add(possibles.getOrDefault(dec, that) -> dec);
            all.add(dec);
        }
    }
    
    shared actual void visit(Tree.SpecifierStatement that) {
        super.visit(that);
        if (is Tree.StaticMemberOrTypeExpression term 
                = that.baseMemberExpression, 
            is TypedDeclaration dec = term.declaration,
            hasOuterRefs(dec, scope, statements) 
                    && isDefinedLocally(dec) &&
                    !dec in all) {
            resultsList.add(possibles.getOrDefault(dec, that) -> dec);
            all.add(dec);
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

shared class FindReturnsVisitor() 
        extends Visitor() {
    value returnsList = ArrayList<Tree.Return>();
    shared List<Tree.Return> returns => returnsList;
    shared actual void visit(Tree.Declaration that) {}
    shared actual void visit(Tree.Return that) {
        super.visit(that);
        if (that.expression exists) {
            returnsList.add(that);
        }
    }
}

"Is the given [[declaration|currentDec]] in scope in the
 first given [[scope]], but out of scope in the second
 given [[target scope|targetScope]]?"
Boolean isLocalReference(Declaration currentDec, 
    Scope scope, Scope targetScope) 
        => (currentDec.isDefinedInScope(scope) 
            || scope.isInherited(currentDec)) &&
           !(currentDec.isDefinedInScope(targetScope) 
            || targetScope.isInherited(currentDec));

class FindLocalReferencesVisitor(Scope scope, Scope targetScope) 
        extends Visitor() {
    
    value results = ArrayList<Tree.BaseMemberExpression>();
    value thisResults = ArrayList<Tree.This>();
    
    shared List<Tree.BaseMemberExpression> localReferences => results;
    shared List<Tree.This> localThisReferences => thisResults;
    
    shared actual void visit(Tree.This that) {
        super.visit(that);
        if (!ModelUtil.contains(that.declarationModel, targetScope)) {
            thisResults.add(that);
        }
    }
    
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
        
        if (isLocalReference(currentDec, scope, targetScope)) {
            results.add(that);
        }
    }
}

shared Tree.Declaration? getTargetNode(Tree.Term term,
    Tree.Declaration? target, 
    Tree.CompilationUnit rootNode) {
    if (exists target) {
        return target;
    }
    else {
        value fsv = FindContainerVisitor(term);
        rootNode.visit(fsv);
        if (exists dec = fsv.declaration) {
            if (is Tree.AttributeDeclaration dec) {
                if (exists container 
                    = nodes.getContainer(rootNode, 
                    dec.declarationModel)) {
                    return container;
                }
                else {
                    return dec;
                }
            }
            else {
                return dec;
            }
        }
        else {
            return null;
        }
    }
}
