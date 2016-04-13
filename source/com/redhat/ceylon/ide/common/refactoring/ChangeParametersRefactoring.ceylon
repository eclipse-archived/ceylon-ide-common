import ceylon.collection {
    HashSet,
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.analyzer {
    TypeVisitor,
    ExpressionVisitor
}
import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer,
    CeylonParser
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree,
    Node,
    Message
}
import com.redhat.ceylon.ide.common.correct {
    DocumentChanges
}
import com.redhat.ceylon.ide.common.model {
    CeylonUnit
}
import com.redhat.ceylon.ide.common.platform {
    IndentsServicesConsumer
}
import com.redhat.ceylon.ide.common.typechecker {
    AnyProjectPhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    FindReferencesVisitor,
    FindRefinementsVisitor,
    ErrorVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Functional,
    Parameter,
    Class,
    FunctionOrValue,
    Type,
    Value,
    Scope
}

import java.util {
    JList=List,
    JHashSet=HashSet
}

import org.antlr.runtime {
    CommonToken,
    ANTLRStringStream,
    CommonTokenStream
}

"Finds out which [[Declaration]] the 'Change Parameters' refactoring
 can work on."
shared <Functional&Declaration>? getDeclarationForChangeParameters
    (Node node, Tree.CompilationUnit rootNode) {
    
    value dec = nodes.getReferencedExplicitDeclaration(node, rootNode);
    
    if (is Functional&Declaration dec,
        is Functional refDec = dec.refinedDeclaration,
        exists pls = refDec.parameterLists,
        !pls.empty) {
        
        return if (is Class dec) 
               then (dec.defaultConstructor else dec)
               else dec;
    }
    
    return null;
}

"Tries to parse a type expression, and returns the corresponding [[Type]] in
 case of success, or a [[String]] indicating a parse/lex error."
shared String|Type parseTypeExpression(String typeText, TypecheckerUnit unit, Scope scope) {
    try {
        value lexer = CeylonLexer(ANTLRStringStream(typeText));
        value ts = CommonTokenStream(lexer);
        ts.fill();
        value lexErrors = lexer.errors;
        
        if (!lexErrors.empty) {
            return lexErrors.get(0).message;
        }
        
        value parser = CeylonParser(ts);
        Tree.StaticType? staticType = parser.type();
        
        if (ts.index() < ts.size() - 1) {
            return "extra tokens in type expression";
        }
        
        value parseErrors = parser.errors;
        if (!parseErrors.empty) {
            return parseErrors.get(0).message;
        }
        
        assert(exists staticType);
    
        staticType.visit(object extends Visitor() {
            shared actual void visitAny(Node that) {
                that.unit = unit;
                that.scope = scope;
                super.visitAny(that);
            }
        });
        staticType.visit(TypeVisitor(unit));
        staticType.visit(ExpressionVisitor(unit));
        
        variable String? err = null;
        
        object extends ErrorVisitor() {
            shared actual void handleMessage(Integer startOffset, Integer endOffset,
                Integer startCol, Integer startLine, Message error) {
                
                err = error.message; 
            }
        }.visit(staticType);
        
        return err else staticType.typeModel;
    } catch (Exception e) {
        return "Could not parse type expression";
    }
}

shared interface ChangeParametersRefactoring<IDocument, InsertEdit, TextEdit, TextChange, Change>
        satisfies AbstractRefactoring<[Change, ParameterList]>
                & DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
                & IndentsServicesConsumer<IDocument>
        given InsertEdit satisfies TextEdit {
    
    class FindInvocationsVisitor(Declaration declaration) extends Visitor() {
        value posResults = HashSet<Tree.PositionalArgumentList>();
        value namedResults = HashSet<Tree.NamedArgumentList>();

        shared Set<Tree.PositionalArgumentList> positionalArgLists => posResults;
        
        shared Set<Tree.NamedArgumentList> namedArgLists => namedResults;
         
        shared actual void visit(Tree.InvocationExpression that) {
            super.visit(that);
            value primary = that.primary;
            if (is Tree.MemberOrTypeExpression mte = primary) {
                value dec = mte.declaration;
                if (dec.refines(declaration)) {
                    if (exists pal = that.positionalArgumentList) {
                        posResults.add(pal);
                    }
                    
                    if (exists nal = that.namedArgumentList) {
                        namedResults.add(nal);
                    }
                }
            }
        }
    }
    
    class FindArgumentsVisitor(Declaration declaration) extends Visitor() {
        shared HashSet<Tree.MethodArgument> results = HashSet<Tree.MethodArgument>();
        
        shared actual void visit(Tree.MethodArgument that) {
            super.visit(that);

            if (exists p = that.parameter,
                p.model == declaration) {
                
                results.add(that);
            }
        }
    }

    // TODO move up, shared with InlineRefacto and probably others
    shared formal TextChange newTextChange(AnyProjectPhasedUnit pu);
    shared formal TextChange newDocChange();
    shared formal void addChangeToChange(Change change, TextChange tc);

    "Applies the changes made in the `ParameterList`."
    shared actual void build([Change, ParameterList] data) {
        value units = getAllUnits();
        // TODO ProgressMonitor
        value [change, params] = data;
        
        for (u in units) {
            if (searchInFile(u), is AnyProjectPhasedUnit u) {
                value tfc = newTextChange(u);
                refactorInFile(params, tfc, change, u.compilationUnit, u.tokens);
            }
        }
        
        if (searchInEditor()) {
            value dc = newDocChange();
            refactorInFile(params, dc, change, editorData.rootNode, editorData.tokens);
        }
    }

    void refactorInFile(ParameterList params, TextChange tfc, Change cc, 
        Tree.CompilationUnit root, JList<CommonToken> tokens) {
        
        initMultiEditChange(tfc);
        
        refactorArgumentLists(params, tfc, root, tokens);
        refactorDeclarations(params, tfc, root, tokens);
        refactorReferences(params, tfc, root);
        
        if (hasChildren(tfc)) {
            addChangeToChange(cc, tfc);
        }
    }

    "An object holding information related to the signature of the function
     being refactored."
    shared class ParameterList(declaration) {
        value params = ArrayList<Param>();

        shared List<Param> parameters => params;
        shared Declaration declaration;
        shared Integer size => params.size;
        shared void add(Param p) => params.add(p);
        
        "Moves the parameter at [[position]] up in the list of parameters."
        shared Boolean moveUp(Integer position) {
            if (0 < position < size) {
                params.swap(position, position - 1);
                return true;
            }
            return false;
        }
        
        "Moves the parameter at [[position]] down in the list of parameters."
        shared Boolean moveDown(Integer position) {
            if (0 <= position < size - 1) {
                params.swap(position, position + 1);
                return true;
            }
            return false;
        }
        
        "Deletes the parameter at [[position]] from the list of parameters."
        shared Boolean delete(Integer position) {
            if (0 <= position < size) {
                params.delete(position);
                return true;
            }
            return false;
        }
        
        "Adds a parameter at the end of the list of parameters."
        shared Param create(String name = "something", Type type = declaration.unit.anythingType) {
            value model = Value();
            model.type = type;
            model.name = name;
            model.container = declaration.scope;
            model.scope = declaration.scope;
            
            value p = Parameter();
            p.model = model;
            p.name = name;
            p.defaulted = false;
            if (is Declaration scope = declaration.scope) {
                p.declaration = scope;
            }
            model.initializerParameter = p;
            
            value param = Param(-1, p);
            params.add(param);
            return param;
        }
        
        "Creates a preview of the function's new signature, based on the current
         changes made to this object."
        shared String previewSignature() {
            value decNode = nodes.getReferencedNode(declaration);
            
            Tree.ParameterList pl;
            Integer startIndex;
            
            if (is Tree.AnyMethod decNode) {
                value m = decNode;
                pl = m.parameterLists.get(0);
                startIndex = m.type.startIndex.intValue();
            } else if (is Tree.AnyClass c = decNode) {
                pl = c.parameterList;
                assert(is CommonToken tok = c.mainToken);
                startIndex = tok.startIndex;
            } else if (is Tree.Constructor decNode) {
                value c = decNode;
                pl = c.parameterList;
                assert(is CommonToken tok = c.mainToken);
                startIndex = tok.startIndex;
            } else {
                return "<unknown>";
            }
            
            if (exists decNode,
                is CeylonUnit ceylonUnit = declaration.unit,
                exists tokens = ceylonUnit.phasedUnit?.tokens) {
                
                value edit = reorderDeclaration(this, pl, false, tokens);
                value start = startIndex - decNode.startIndex.intValue();
                value end = pl.startIndex.intValue() - decNode.startIndex.intValue();
                
                return nodes.text(tokens, decNode).substring(start, end)
                        + getInsertedText(edit);
            }
            
            return "<unknown>";
        }
    }

    "Holds information related to a given parameter of the function being
     refactored."
    shared class Param(position, model, name = model.name,
            initDefaulted = model.defaulted,
            initDefaultArgs = null, originalDefaultArgs = initDefaultArgs, 
            paramList = null) {
        
        Boolean initDefaulted;
        String? initDefaultArgs;
        
        "The original position in the list of parameters."
        shared Integer position;
        shared variable String name;
        shared Parameter model;
        shared variable Boolean defaulted = initDefaulted;
        shared variable String? defaultArgs = initDefaultArgs;
        shared String? originalDefaultArgs;
        shared String? paramList;
        
        shared Boolean defaultHasChanged => 
                if (defaulted, 
                    exists originalDefaultArgs,
                    originalDefaultArgs != (defaultArgs else 1))
                then true else false;
    }
    
    "Creates a new [[ParameterList]] that can be modified in the UI.
     Call [[ChangeParametersRefactoring.build]] to apply changes."
    shared ParameterList? computeParameters() {
        if (exists decl = getDeclarationForChangeParameters(editorData.node, rootNode),
            is Functional refDec = decl.refinedDeclaration,
            exists pls = refDec.parameterLists) {
            
            value pl = switch (decNode = nodes.getReferencedNode(refDec))
            case (is Tree.AnyClass) decNode.parameterList
            case (is Tree.Constructor) decNode.parameterList
            case (is Tree.AnyMethod) decNode.parameterLists.get(0)
            else null;
            
            value info = ParameterList(decl);
            
            assert(exists pl);
            
            value params = zipPairs(
                CeylonIterable(pls.get(0).parameters), 
                CeylonIterable(pl.parameters)
            );
            
            for ([pModel, pTree] in params) {
                value _defaultArgs = if (exists sie = nodes.getDefaultArgSpecifier(pTree))
                then nodes.text(editorData.tokens, sie.expression)
                else null;
                value _paramList = if (is Tree.FunctionalParameterDeclaration pTree,
                    is Tree.MethodDeclaration pd = pTree.typedDeclaration)
                then nodes.text(editorData.tokens, pd.parameterLists.get(0))
                else null;
                
                value p = Param( 
                    info.size,
                    pModel,
                    pModel.name,
                    pModel.defaulted,
                    _defaultArgs,
                    _defaultArgs,
                    _paramList
                );
                info.add(p);
            }
            
            return info;
        }

        return null;
    }
    
    "Counts all the references to the function being refactored."
    shared Integer countAllReferences(ParameterList list, Tree.CompilationUnit cu) {
        value frv = FindInvocationsVisitor(list.declaration);
        value fdv = FindRefinementsVisitor(list.declaration);
        value fav = FindArgumentsVisitor(list.declaration);

        cu.visit(frv);
        cu.visit(fdv);
        cu.visit(fav);

        return frv.positionalArgLists.size 
                + fdv.declarationNodes.size
                + fav.results.size;
    }

    name => "Change Parameter List";
    affectsOtherFiles => true;

    void refactorReferences(ParameterList list, TextChange tfc, 
        Tree.CompilationUnit root) {
        
        for (p in list.parameters) {
            value param = p.model;
            value model = param.model;
            value newName = p.name;
            
            value fprv = object extends FindReferencesVisitor(model) {
                shared actual void visit(Tree.InitializerParameter that) {
                    //initializer parameters will be handled when
                    //we refactor the parameter list
                    if (exists se = that.specifierExpression) {
                        se.visit(this);
                    }
                }
                
                shared actual void visit(Tree.ParameterDeclaration that) {
                    //don't confuse a parameter declaration with
                    //a split declaration below
                    value td = that.typedDeclaration;
                    if (is Tree.AttributeDeclaration ad = td,
                        exists se = ad.specifierOrInitializerExpression) {
                        se.visit(this);
                    }
                    
                    if (is Tree.MethodDeclaration md = td,
                        exists se = md.specifierExpression) {
                        se.visit(this);
                    }
                }
                
                shared actual void visit(Tree.TypedDeclaration that) {
                    //handle split declarations
                    super.visit(that);
                    if (exists id = that.identifier,
                        isReference(that.declarationModel),
                        is JHashSet<Node> _nodes = nodeSet) {
                        
                        _nodes.add(that);
                    }
                }
                
                shared actual Boolean isReference(Parameter|Declaration? p) {
                    if (is Parameter p) {
                        return isSameParameter(param, p);
                    } else if (is Declaration ref = p, ref.parameter) {
                        assert (is FunctionOrValue fov = ref);
                        return isSameParameter(param, fov.initializerParameter);
                    }
                    return false;
                }
            };
            root.visit(fprv);
            
            for (ref in fprv.nodeSet) {
                value idn = nodes.getIdentifyingNode(ref);
                if (is Tree.Identifier idn) {
                    value id = idn;
                    if (!id.text.equals(newName)) {
                        addEditToChange(tfc, 
                            newReplaceEdit(id.startIndex.intValue(), 
                                id.distance.intValue(), newName));
                    }
                }
            }
        }
    }

    void refactorDeclarations(ParameterList list, TextChange tfc,
        Tree.CompilationUnit root, JList<CommonToken> tokens) {
        
        value frv = FindRefinementsVisitor(list.declaration);
        root.visit(frv);
        for (decNode in frv.declarationNodes) {
            variable Boolean actual;
            variable Tree.ParameterList pl;
            if (is Tree.AnyMethod decNode) {
                value m = decNode;
                pl = m.parameterLists.get(0);
                actual = m.declarationModel.actual;
            } else if (is Tree.AnyClass decNode) {
                value c = decNode;
                pl = c.parameterList;
                actual = c.declarationModel.actual;
            } else if (is Tree.Constructor decNode) {
                value c = decNode;
                pl = c.parameterList;
                actual = c.declarationModel.actual;
            } else if (is Tree.SpecifierStatement decNode) {
                value ss = decNode;
                value bme = ss.baseMemberExpression;
                if (is Tree.ParameterizedExpression bme) {
                    value pe = bme;
                    pl = pe.parameterLists.get(0);
                    actual = true;
                } else {
                    continue;
                }
            } else {
                continue;
            }
            
            addEditToChange(tfc, reorderDeclaration(list, pl, actual, tokens));
        }
    }
    
    TextEdit reorderDeclaration(ParameterList list, Tree.ParameterList pl, 
        Boolean actual, JList<CommonToken> tokens) {
        
        value sb = StringBuilder().append("(");
        value params = CeylonIterable(pl.parameters);
        
        for (p in list.parameters) {
            variable String paramString = "";
            
            if (exists oldParam = params.find((oldP) => isSameParameter(oldP.parameterModel, p.model))) {
                paramString = paramStringWithoutDefaultArg(oldParam, p.name, tokens);
                
                if (p.defaulted, !actual) {
                    // now add the new default arg
                    // TODO: this results in incorrectly-typed
                    // code for void functional parameters
                    paramString = paramString 
                            + getSpecifier(oldParam)
                            + getNewDefaultArg(p);
                }
            } else {
                paramString = p.model.type.asString(pl.unit) + " " + p.name;
                
                if (p.defaulted, !actual) {
                    paramString += " = " + (p.defaultArgs else "nothing");
                }
            }
            
            sb.append(paramString).append(", ");
        }
        
        if (sb.endsWith(", ")) {
            sb.deleteTerminal(2);
        }
        
        sb.append(")");
        
        return newReplaceEdit(pl.startIndex.intValue(), 
            pl.distance.intValue(), sb.string);

    }

    Boolean isSameParameter(Parameter? x, Parameter? y) {
        if (exists x, exists y,
            is Functional fx = x.declaration,
            is Functional fy = y.declaration) { 

            value xpl = fx.parameterLists;
            value ypl = fy.parameterLists;
            return !xpl.empty && !ypl.empty
                    && fx.refinedDeclaration == fy.refinedDeclaration
                    && xpl.get(0).parameters.indexOf(x) ==
                        ypl.get(0).parameters.indexOf(y);
        }
        
        return false;
    }

    void refactorArgumentLists(ParameterList list, TextChange tfc, 
        Tree.CompilationUnit root, JList<CommonToken> tokens) {
        
        value fiv = FindInvocationsVisitor(list.declaration);
        root.visit(fiv);

        // Fix positional argument lists in callers
        for (pal in fiv.positionalArgLists) {
            addEditToChange(tfc, reorderArguments(list, pal, tokens));
        }
        
        // Fix named argument lists in callers
        for (nal in fiv.namedArgLists) {
            variable Tree.NamedArgument? last = null;
            
            // Remove args that don't exist anymore
            for (na in nal.namedArguments) {
                if (exists nap = na.parameter, 
                    !exists _ = list.parameters.find((p) => isSameParameter(p.model, nap))) {
                    
                    value start = if (exists _last = last)
                                  then _last.endIndex.intValue()
                                  else nal.startIndex.intValue() + 1;
                    addEditToChange(tfc, newDeleteEdit(start, 
                            na.endIndex.intValue() - start));
                }
                last = na;
            }
            
            // Add new args
            for (p in list.parameters) {
                value nas = CeylonIterable(nal.namedArguments);

                if (!p.defaulted || p.defaultHasChanged,
                    !exists _ = nas.find((na) => isSameParameter(na.parameter, p.model))) {
                    
                    variable value argString = getInlinedNamedArg(p, p.defaultArgs);
                    value startOffset = nal.startIndex.intValue();
                    value stopOffset = nal.stopIndex.intValue();
                    value doc = getDocumentForChange(tfc);
                    
                    if (getLineOfOffset(doc, stopOffset) > getLineOfOffset(doc, startOffset)) {
                        argString = indents.defaultIndent + argString + ";"
                                + indents.getDefaultLineDelimiter(doc)
                                + indents.getIndent(nal, doc);
                    } else if (startOffset == stopOffset-1) {
                        argString = " " + argString + "; ";
                    } else {
                        argString = argString + "; ";
                    }
                    
                    addEditToChange(tfc, newInsertEdit(stopOffset, argString));
                }
            }
        }
        
        // Fix the parameter list
        value fav = FindArgumentsVisitor(list.declaration);
        root.visit(fav);
        for (decNode in fav.results) {
            value pl = decNode.parameterLists.get(0);
            addEditToChange(tfc, reorderParameters(list, pl, tokens));
        }
    }
    
    TextEdit reorderArguments(ParameterList list, Tree.PositionalArgumentList pal,
        JList<CommonToken> tokens) {
        
        value oldArgs = CeylonIterable(pal.positionalArguments);
        value builder = StringBuilder().append("(");
        
        for (p in list.parameters) {
            if (exists oldVal = oldArgs.find((oa) => isSameParameter(oa.parameter, p.model))) {
                builder.append(nodes.text(tokens, oldVal));
            } else {
                builder.append(getInlinedArg(p));
            }
            builder.append(", ");
        }
        
        if (builder.endsWith(", ")) {
            builder.deleteTerminal(2);
        }
        builder.append(")");
        
        return newReplaceEdit(
            pal.startIndex.intValue(), 
            pal.distance.intValue(),
            builder.string
        );
    }

    TextEdit reorderParameters(ParameterList list, Tree.ParameterList pal,
        JList<CommonToken> tokens) {
        
        value oldArgs = CeylonIterable(pal.parameters);
        value builder = StringBuilder().append("(");
        
        for (p -> pTree in zipEntries(list.parameters, oldArgs)) {
            builder.append(paramString(pTree, p.name, tokens))
                    .append(", ");
        }
        
        if (builder.endsWith(", ")) {
            builder.deleteTerminal(2);
        }
        builder.append(")");
        
        return newReplaceEdit(
            pal.startIndex.intValue(), 
            pal.distance.intValue(),
            builder.string
        );
    }
    
    String paramString(Tree.Parameter parameter, String newName, 
        JList<CommonToken> tokens) {
        
        value paramString = nodes.text(tokens, parameter);
        value loc = parameter.startIndex.intValue();
        value id = getIdentifier(parameter);
        value start = id.startIndex.intValue() - loc;
        value end = id.endIndex.intValue() - loc;
        return paramString.substring(0, start)
                 + newName + paramString.substring(end);
    }
    
    String paramStringWithoutDefaultArg(Tree.Parameter parameter, String newName,
        JList<CommonToken> tokens) {
        
        variable String paramString = nodes.text(tokens, parameter);
        // first remove the default arg
        value sie = nodes.getDefaultArgSpecifier(parameter);
        value loc = parameter.startIndex.intValue();
        if (exists sie) {
            value start = sie.startIndex.intValue() - loc;
            paramString = paramString.substring(0, start).trimmed;
        }
        
        value id = getIdentifier(parameter);
        value start = id.startIndex.intValue() - loc;
        value end = id.endIndex.intValue() - loc;
        return paramString.substring(0, start) 
                + newName + paramString.substring(end);
    }
    
    Tree.Identifier getIdentifier(Tree.Parameter parameter) {
        if (is Tree.InitializerParameter parameter) {
            value ip = parameter;
            return ip.identifier;
        } else if (is Tree.ParameterDeclaration parameter) {
            value pd = parameter;
            return pd.typedDeclaration.identifier;
        } else {
            throw Exception();
        }
    }
    
    String getSpecifier(Tree.Parameter parameter) {
        if (is Tree.FunctionalParameterDeclaration parameter) {
            return " => ";
        } else {
            return " = ";
        }
    }
    
    String getInlinedArg(Param p) {
        String val;
        value argString = p.defaultArgs;
        
        if (exists argString, !argString.empty) {
            val = argString;
        } else {
            value defaultArg = p.originalDefaultArgs;
            if (exists defaultArg, !defaultArg.empty) {
                val = defaultArg;
            } else {
                val = "nothing";
            }
        }
        
        if (exists params = p.paramList) {
            return params + " => " + val;
        }
        
        return val;
    }
    
    String getInlinedNamedArg(Param p, String? argString) {
        String val;
        if (exists argString, !argString.empty) {
            val = argString;
        } else {
            value originalArg = p.originalDefaultArgs;
            if (exists originalArg, !originalArg.empty) {
                val = originalArg;
            } else {
                val = "nothing";
            }
        }
        
        value paramList = p.paramList;
        if (!exists paramList) {
            return p.name + " = " + val;
        } else {
            return "function " + p.name + paramList + " => " + val;
        }
    }
    
    String getNewDefaultArg(Param p) {
        String? argString = p.defaultArgs;
        
        if (exists argString, !argString.empty) {
            return argString;
        }
        
        return "nothing";
    }

}