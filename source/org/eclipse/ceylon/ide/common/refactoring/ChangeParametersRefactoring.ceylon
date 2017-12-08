/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    HashSet,
    ArrayList,
    MutableSet
}

import org.eclipse.ceylon.compiler.typechecker.analyzer {
    TypeVisitor,
    ExpressionVisitor
}
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.compiler.typechecker.parser {
    CeylonLexer,
    CeylonParser
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Visitor,
    Tree,
    Node,
    Message
}
import org.eclipse.ceylon.ide.common.model {
    CeylonUnit
}
import org.eclipse.ceylon.ide.common.platform {
    CompositeChange,
    platformServices,
    TextChange,
    CommonDocument,
    TextEdit,
    ReplaceEdit,
    DeleteEdit,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.typechecker {
    AnyProjectPhasedUnit,
    AnyEditedPhasedUnit
}
import org.eclipse.ceylon.ide.common.util {
    nodes,
    FindReferencesVisitor,
    FindRefinementsVisitor,
    ErrorVisitor
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Functional,
    Parameter,
    Class,
    FunctionOrValue,
    Type,
    Value,
    Scope,
    Unit,
    Cancellable
}

import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken,
    ANTLRStringStream,
    CommonTokenStream
}
import java.lang {
    overloaded
}

"Finds out which [[Declaration]] the 'Change Parameters' refactoring
 can work on."
shared <Functional&Declaration>? getDeclarationForChangeParameters
        (Node node, Tree.CompilationUnit rootNode) {
    if (is Functional&Declaration dec 
            = nodes.getReferencedExplicitDeclaration(node, rootNode),
        is Functional refDec 
            = dec.refinedDeclaration,
        exists pls = refDec.parameterLists,
        !pls.empty) {
        return 
            if (is Class dec, 
                exists dc = dec.defaultConstructor) 
            then dc
            else dec;
    }
    else {
        return null;
    }
}

"Tries to parse a type expression, and returns the corresponding [[Type]] in
 case of success, or a [[String]] indicating a parse/lex error."
shared String|Type parseTypeExpression(String typeText, Unit unit, Scope scope) {
    try {
        value lexer = CeylonLexer(ANTLRStringStream(typeText));
        value ts = CommonTokenStream(lexer);
        ts.fill();
        if (exists err = lexer.errors[0]) {
            return err.message;
        }
        
        value parser = CeylonParser(ts);
        Tree.StaticType? staticType = parser.type();
        if (ts.index() < ts.size() - 1) {
            return "extra tokens in type expression";
        }
        if (exists err = parser.errors[0]) {
            return err.message;
        }
        assert (exists staticType);
    
        staticType.visit(object extends Visitor() {
            shared actual void visitAny(Node that) {
                that.unit = unit;
                that.scope = scope;
                super.visitAny(that);
            }
        });
        staticType.visit(TypeVisitor(unit, Cancellable.alwaysCancelled));
        staticType.visit(ExpressionVisitor(unit, Cancellable.alwaysCancelled));
        
        variable String? err = null;
        
        object extends ErrorVisitor() {
            handleMessage(
                Integer startOffset, Integer endOffset,
                Integer startCol, Integer startLine, 
                Message error) 
                    => err = error.message;
        }.visit(staticType);
        
        return err else staticType.typeModel;
    }
    catch (e) {
        return "Could not parse type expression";
    }
}

class FindInvocationsVisitor(Declaration declaration) 
        extends Visitor() {
    value posResults = HashSet<Tree.PositionalArgumentList>();
    value namedResults = HashSet<Tree.NamedArgumentList>();
    
    shared Set<Tree.PositionalArgumentList> positionalArgLists => posResults;        
    shared Set<Tree.NamedArgumentList> namedArgLists => namedResults;
    
    shared actual void visit(Tree.InvocationExpression that) {
        super.visit(that);
        if (is Tree.MemberOrTypeExpression mte = that.primary,
            exists d = mte.declaration, 
            d.refines(declaration)) {
            if (exists pal = that.positionalArgumentList) {
                posResults.add(pal);
            }
            if (exists nal = that.namedArgumentList) {
                namedResults.add(nal);
            }
        }
    }
}

class FindArgumentsVisitor(Declaration declaration) 
        extends Visitor() {
    shared MutableSet<Tree.MethodArgument> results 
            = HashSet<Tree.MethodArgument>();
    
    shared actual void visit(Tree.MethodArgument that) {
        super.visit(that);
        if (exists p = that.parameter,
            p.model == declaration) {
            results.add(that);
        }
    }
}

shared abstract class ChangeParametersRefactoring(
    Tree.CompilationUnit rootNode,
    Integer selectionStart,
    Integer selectionEnd,
    JList<CommonToken> tokens,
    CommonDocument doc,
    PhasedUnit phasedUnit,
    {PhasedUnit*} allUnits
)
        satisfies Refactoring {

    shared formal Boolean searchInFile(PhasedUnit pu);
    shared formal Boolean searchInEditor();
    shared formal Boolean inSameProject(Functional&Declaration declaration);
    
    value node = nodes.findNode { 
        node = rootNode; 
        tokens = tokens; 
        startOffset = selectionStart; 
        endOffset = selectionEnd;
    };
    value declaration 
            = if (exists node)
            then getDeclarationForChangeParameters(node, rootNode)
            else null;
    
    enabled => if (is Functional declaration)
               then inSameProject(declaration)
               else false;
    
    shared Boolean affectsOtherFiles 
            => if (exists declaration) 
            then declaration.toplevel || declaration.shared 
            else false;
    
    "Applies the changes made in the `ParameterList`."
    shared CompositeChange build(ParameterList params) {
        
        value change 
                = platformServices.document
                    .createCompositeChange(name);
        
        // TODO progress reporting!
        if (affectsOtherFiles) {
            for (phasedUnit in allUnits) {
                if (searchInFile(phasedUnit)) {
                    assert (is AnyProjectPhasedUnit phasedUnit);
                    refactorInFile {
                        params = params;
                        tfc = platformServices.document
                                .createTextChange(name, phasedUnit);
                        cc = change;
                        root = phasedUnit.compilationUnit;
                        tokens = phasedUnit.tokens;
                    };
                }
            }
        }
        else {
            if (searchInFile(phasedUnit)) {
                assert (is AnyEditedPhasedUnit phasedUnit);
                refactorInFile {
                    params = params;
                    tfc = platformServices.document
                            .createTextChange(name, phasedUnit);
                    cc = change;
                    root = phasedUnit.compilationUnit;
                    tokens = phasedUnit.tokens;
                };
            }
        }
        
        if (searchInEditor()) {
            refactorInFile {
                params = params;
                tfc = platformServices.document
                        .createTextChange(name, doc);
                cc = change;
                root = rootNode;
                tokens = tokens;
            };
        }
        
        return change;
    }

    void refactorInFile(ParameterList params, TextChange tfc, CompositeChange cc, 
        Tree.CompilationUnit root, JList<CommonToken> tokens) {
        
        tfc.initMultiEdit();
        
        refactorArgumentLists {
            list = params;
            tfc = tfc;
            root = root;
            tokens = tokens;
        };
        refactorDeclarations {
            list = params;
            tfc = tfc;
            root = root;
            tokens = tokens;
        };
        refactorReferences {
            list = params;
            tfc = tfc;
            root = root;
        };
        
        if (tfc.hasEdits) {
            cc.addTextChange(tfc);
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
        shared Param create(String name = "something", 
                Type type = declaration.unit.anythingType) {
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
        
        "Creates a preview of the function's new signature, 
         based on the current changes made to this object."
        shared String previewSignature() {
            value decNode = nodes.getReferencedNode(declaration, rootNode);
            
            Tree.ParameterList pl;
            Integer startIndex;
            
            switch (decNode)
            case (is Tree.AnyMethod) {
                pl = decNode.parameterLists.get(0);
                startIndex = decNode.type.startIndex.intValue();
            }
            case (is Tree.AnyClass) {
                pl = decNode.parameterList;
                assert(is CommonToken tok = decNode.mainToken);
                startIndex = tok.startIndex;
            }
            case (is Tree.Constructor) {
                value c = decNode;
                pl = c.parameterList;
                assert(is CommonToken tok = c.mainToken);
                startIndex = tok.startIndex;
            }
            else {
                return "<unknown>";
            }
            
            if (exists decNode,
                is CeylonUnit ceylonUnit = declaration.unit,
                exists tokens = ceylonUnit.phasedUnit?.tokens) {
                
                value edit = reorderDeclaration {
                    list = this;
                    pl = pl;
                    actual = false;
                    tokens = tokens;
                };
                value start 
                        = startIndex 
                        - decNode.startIndex.intValue();
                value end 
                        = pl.startIndex.intValue() 
                        - decNode.startIndex.intValue();
                
                return nodes.text(tokens, decNode)
                        .substring(start, end)
                            + edit.text;
            }
            
            return "<unknown>";
        }
    }

    "Holds information related to a given parameter of the function being
     refactored."
    shared class Param(position, model, 
            name = model.name,
            initDefaulted = model.defaulted,
            initDefaultArgs = null, 
            originalDefaultArgs = initDefaultArgs, 
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
        
        shared Boolean defaultHasChanged 
                => if (defaulted, exists originalDefaultArgs)
                then originalDefaultArgs != (defaultArgs else 1)
                else false;
    }
    
    "Creates a new [[ParameterList]] that can be modified in the UI.
     Call [[ChangeParametersRefactoring.build]] to apply changes."
    shared ParameterList? computeParameters() {
        if (exists declaration,
            is Functional refDec = declaration.refinedDeclaration,
            exists pl = refDec.firstParameterList,
            exists plNode
                    = switch (decNode = nodes.getReferencedNode(refDec, rootNode))
                    case (is Tree.AnyMethod) decNode.parameterLists[0]
                    case (is Tree.AnyClass) decNode.parameterList
                    case (is Tree.Constructor) decNode.parameterList
                    else null) {
            
            value info = ParameterList(declaration);
            variable value i = 0;
            while (exists pModel = pl.parameters[i],
                   exists pTree = plNode.parameters[i]) {
                info.add(Param { 
                    position = i++; 
                    model = pModel; 
                    name = pModel.name; 
                    initDefaulted = pModel.defaulted; 
                    initDefaultArgs 
                            = if (exists sie = nodes.getDefaultArgSpecifier(pTree))
                            then nodes.text(tokens, sie.expression)
                            else null; 
                    paramList
                            = if (is Tree.FunctionalParameterDeclaration pTree,
                                  is Tree.MethodDeclaration pd = pTree.typedDeclaration,
                                  exists ppl = pd.parameterLists[0])
                            then nodes.text(tokens, ppl)
                            else null;
                });
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
    
    void refactorReferences(ParameterList list, TextChange tfc, 
        Tree.CompilationUnit root) {
        
        for (p in list.parameters) {
            value param = p.model;
            
            object fprv extends FindReferencesVisitor(param.model) {
                overloaded
                shared actual void visit(Tree.InitializerParameter that) {
                    //initializer parameters will be handled when
                    //we refactor the parameter list
                    if (exists se = that.specifierExpression) {
                        se.visit(this);
                    }
                }

                overloaded
                shared actual void visit(Tree.ParameterDeclaration that) {
                    //don't confuse a parameter declaration with
                    //a split declaration below
                    value td = that.typedDeclaration;
                    if (is Tree.AttributeDeclaration td,
                        exists se = td.specifierOrInitializerExpression) {
                        se.visit(this);
                    }
                    if (is Tree.MethodDeclaration td,
                        exists se = td.specifierExpression) {
                        se.visit(this);
                    }
                }

                overloaded
                shared actual void visit(Tree.TypedDeclaration that) {
                    //handle split declarations
                    super.visit(that);
                    if (exists id = that.identifier,
                        isReference(that.declarationModel)) {
                        nodesMutator.add(that);
                    }
                }

                overloaded
                shared actual Boolean isReference(Parameter|Declaration? p) {
                    if (is Parameter p) {
                        return isSameParameter(param, p);
                    } else if (is Declaration p, p.parameter) {
                        assert (is FunctionOrValue p);
                        return isSameParameter(param, p.initializerParameter);
                    }
                    else {
                        return false;
                    }
                }
            }
            root.visit(fprv);
            
            value newName = p.name;
            for (ref in fprv.referenceNodes) {
                if (is Tree.Identifier id 
                        = nodes.getIdentifyingNode(ref), 
                    !id.text==newName) {
                    tfc.addEdit(
                        ReplaceEdit {
                            start = id.startIndex.intValue();
                            length = id.distance.intValue();
                            text = newName;
                        }
                    );
                }
            }
        }
    }

    void refactorDeclarations(ParameterList list, TextChange tfc,
        Tree.CompilationUnit root, JList<CommonToken> tokens) {
        
        value frv = FindRefinementsVisitor(list.declaration);
        root.visit(frv);
        for (decNode in frv.declarationNodes) {
            Boolean actual;
            Tree.ParameterList? pl;
            switch (decNode)
            case (is Tree.AnyMethod) {
                pl = decNode.parameterLists[0];
                actual = decNode.declarationModel.actual;
            }
            case (is Tree.AnyClass) {
                pl = decNode.parameterList;
                actual = decNode.declarationModel.actual;
            }
            case (is Tree.Constructor) {
                pl = decNode.parameterList;
                actual = decNode.declarationModel.actual;
            }
            case (is Tree.SpecifierStatement) {
                if (is Tree.ParameterizedExpression bme
                        = decNode.baseMemberExpression) {
                    pl = bme.parameterLists[0];
                    actual = true;
                }
                else {
                    continue;
                }
            }
            else {
                continue;
            }
            if (!exists pl) {
                continue;
            }
            
            tfc.addEdit( 
                reorderDeclaration {
                    list = list;
                    pl = pl;
                    actual = actual;
                    tokens = tokens;
                }
            );
        }
    }
    
    TextEdit reorderDeclaration(ParameterList list, 
        Tree.ParameterList pl, 
        Boolean actual, JList<CommonToken> tokens) {
        
        value sb = StringBuilder().append("(");
        value params = { *pl.parameters };
        
        for (p in list.parameters) {
            
            if (exists oldParam 
                    = params.find((op)
                        => isSameParameter(op.parameterModel, 
                                           p.model))) {
                sb.append(paramStringWithoutDefaultArg {
                    parameter = oldParam;
                    newName = p.name;
                    tokens = tokens;
                });
                
                if (p.defaulted, !actual) {
                    // now add the new default arg
                    // TODO: this results in incorrectly-typed
                    // code for void functional parameters
                    sb.append(getSpecifier(oldParam))
                      .append(getNewDefaultArg(p));
                }
            }
            else {
                sb.append(p.model.type.asString(pl.unit)).append(" ").append(p.name);
                if (p.defaulted, !actual) {
                    sb.append(" = ").append(p.defaultArgs else "nothing");
                }
            }
            
            sb.append(", ");
        }
        
        if (sb.endsWith(", ")) {
            sb.deleteTerminal(2);
        }
        
        sb.append(")");
        
        return ReplaceEdit { 
            start = pl.startIndex.intValue(); 
            length = pl.distance.intValue(); 
            text = sb.string;
        };

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
            tfc.addEdit( 
                reorderArguments {
                    list = list;
                    pal = pal;
                    tokens = tokens;
                }
            );
        }
        
        // Fix named argument lists in callers
        for (nal in fiv.namedArgLists) {
            variable Tree.NamedArgument? last = null;
            
            // Remove args that don't exist anymore
            for (na in nal.namedArguments) {
                if (exists nap = na.parameter, 
                    !list.parameters.find((p) 
                        => isSameParameter(p.model, nap))
                            exists) {
                    
                    value start 
                            = if (exists _last = last)
                            then _last.endIndex.intValue()
                            else nal.startIndex.intValue() + 1;
                    tfc.addEdit(
                        DeleteEdit { 
                            start = start;
                            length = na.endIndex.intValue() - start;
                        }
                    );
                }
                last = na;
            }
            
            // Add new args
            for (p in list.parameters) {
                value nas = { *nal.namedArguments };

                if (!p.defaulted || p.defaultHasChanged,
                    !nas.find((na) 
                        => isSameParameter(na.parameter, p.model)) 
                            exists) {
                    
                    value startOffset = nal.startIndex.intValue();
                    value stopOffset = nal.stopIndex.intValue();
                    
                    value inarg = getInlinedNamedArg(p, p.defaultArgs);
                    String argString;
                    if (doc.getLineOfOffset(stopOffset) 
                            > doc.getLineOfOffset(startOffset)) {
                        argString = 
                                platformServices.document.defaultIndent 
                                + inarg + ";"
                                + doc.defaultLineDelimiter
                                + doc.getIndent(nal);
                    } else if (startOffset == stopOffset-1) {
                        argString = " " + inarg + "; ";
                    } else {
                        argString = inarg + "; ";
                    }
                    
                    tfc.addEdit( 
                        InsertEdit { 
                            start = stopOffset;
                            text = argString;
                        }
                    );
                }
            }
        }
        
        // Fix the parameter list
        value fav = FindArgumentsVisitor(list.declaration);
        root.visit(fav);
        for (decNode in fav.results) {
             tfc.addEdit(
                reorderParameters {
                    list = list;
                    pal = decNode.parameterLists.get(0);
                    tokens = tokens;
                }
            );
        }
    }
    
    TextEdit reorderArguments(ParameterList list, 
        Tree.PositionalArgumentList pal,
        JList<CommonToken> tokens) {
        
        value oldArgs = { *pal.positionalArguments };
        value builder = StringBuilder().append("(");
        
        for (p in list.parameters) {
            if (exists oldVal 
                    = oldArgs.find((oa) 
                        => isSameParameter(oa.parameter, 
                                           p.model))) {
                builder.append(nodes.text(tokens, oldVal))
                    .append(", ");
            } else if (!p.defaulted) {
                builder.append(getInlinedArg(p))
                    .append(", ");
            }
        }
        
        if (builder.endsWith(", ")) {
            builder.deleteTerminal(2);
        }
        builder.append(")");
        
        return ReplaceEdit { 
            start = pal.startIndex.intValue(); 
            length = pal.distance.intValue(); 
            text = builder.string;
        };
    }

    TextEdit reorderParameters(ParameterList list, 
        Tree.ParameterList pal,
        JList<CommonToken> tokens) {
        
        value oldArgs = { *pal.parameters };
        value builder = StringBuilder().append("(");
        
        for (p -> pTree in zipEntries(list.parameters, oldArgs)) {
            builder.append(paramString(pTree, p.name, tokens))
                   .append(", ");
        }
        
        if (builder.endsWith(", ")) {
            builder.deleteTerminal(2);
        }
        builder.append(")");
        
        return ReplaceEdit { 
            start = pal.startIndex.intValue(); 
            length = pal.distance.intValue(); 
            text = builder.string;
        };
    }
    
    function getIdentifier(Tree.Parameter parameter) {
        switch (parameter)
        case (is Tree.InitializerParameter) {
            return parameter.identifier;
        }
        case (is Tree.ParameterDeclaration) {
            return parameter.typedDeclaration.identifier;
        }
        else {
            throw Exception();
        }
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
    
    String paramStringWithoutDefaultArg(
        Tree.Parameter parameter, 
        String newName,
        JList<CommonToken> tokens) {
        
        variable String paramString 
                = nodes.text(tokens, parameter);
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
                + newName 
                + paramString.substring(end);
    }
    
    String getSpecifier(Tree.Parameter parameter) 
            => if (is Tree.FunctionalParameterDeclaration parameter) 
            then " => " else " = ";
    
    String getInlinedArg(Param p) {
        String val;
        if (exists argString = p.defaultArgs, 
            !argString.empty) {
            val = argString;
        }
        else if (exists defaultArg = p.originalDefaultArgs, 
            !defaultArg.empty) {
            val = defaultArg;
        }
        else {
            val = "nothing";
        }
        
        return 
            if (exists params = p.paramList) 
            then params + " => " + val 
            else val;
    }
    
    String getInlinedNamedArg(Param p, String? argString) {
        String val;
        if (exists argString, 
            !argString.empty) {
            val = argString;
        } else if (exists originalArg = p.originalDefaultArgs, 
            !originalArg.empty) {
            val = originalArg;
        } else {
            val = "nothing";
        }
        
        return if (exists paramList = p.paramList) 
            then "function " + p.name + paramList + " => " + val 
            else p.name + " = " + val;
    }
    
    String getNewDefaultArg(Param p) 
            => if (exists argString = p.defaultArgs, 
                    !argString.empty) 
            then argString else "nothing";

}