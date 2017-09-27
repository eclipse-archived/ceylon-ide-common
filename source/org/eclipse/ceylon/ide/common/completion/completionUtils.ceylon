import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    TreeUtil,
    Visitor
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import org.eclipse.ceylon.ide.common.util {
    OccurrenceLocation,
    nodes,
    escaping
}
import org.eclipse.ceylon.model.typechecker.model {
    Parameter,
    ParameterList,
    Value,
    Unit,
    Declaration,
    Package,
    Functional,
    DeclarationWithProximity,
    Scope,
    Function,
    Class,
    Type,
    TypeDeclaration,
    Interface,
    Constructor,
    TypeParameter,
    ModelUtil {
        isTypeUnknown
    },
    Cancellable
}

import java.util {
    JList=List,
    ArrayList,
    Arrays,
    Collections
}

import org.antlr.runtime {
    CommonToken,
    Token
}

shared Boolean isLocation(loc1, loc2) {

    OccurrenceLocation? loc1;
    OccurrenceLocation loc2;

    if (exists loc1) {
        return loc1 == loc2;
    }
    return false;
}

shared String anonFunctionHeader(Type? requiredType, Unit unit, Parameter? param = null) {
    value text = StringBuilder();
    text.append("(");
    
    variable value c = 'a';
    value params
            = if (is Functional fun = param?.model)
            then fun.firstParameterList?.parameters
            else null;
    variable value index = 0;
    for (paramType in unit.getCallableArgumentTypes(requiredType)) {
        if (index>0) {
            text.append(", ");
        }
        if (paramType.entry && !isTypeUnknown(paramType)) {
            text.append(unit.getKeyType(paramType).asSourceCodeString(unit))
                .append(" ");
            if (exists params, exists p = params[index]) {
                text.append(p.name).append("Key");
            } else {
                text.append(c.string);
                c++;
            }
            text.append(" -> ");
            text.append(unit.getValueType(paramType).asSourceCodeString(unit))
                .append(" ");
            if (exists params, exists p = params[index]) {
                text.append(p.name).append("Item");
            } else {
                text.append(c.string);
                c++;
            }
        }
        else {
            text.append(paramType.asSourceCodeString(unit))
                .append(" ");
            if (exists params, exists p = params[index]) {
                text.append(p.name);
            } else {
                text.append(c.string);
                c++;
            }
        }
        index++;
    }
    text.append(")");
    
    return text.string;
}

shared DefaultRegion getCurrentSpecifierRegion(CommonDocument document, Integer offset) {
    variable Integer length = 0;
    variable Integer i = offset;
    while (i < document.size) {
        value ch = document.getChar(i);
        if (ch.whitespace || ch==';' || ch==',' || ch==')') {
            break;
        }
        
        length++;
        i++;
    }
    
    return DefaultRegion(offset, length);
}


shared String getProposedName(Declaration? qualifier, Declaration dec, Unit unit) {
    value buf = StringBuilder();
    if (exists qualifier) {
        buf.append(escaping.escapeName(qualifier, unit))
            .append(".");
    }
    
    if (is Constructor dec) {
        value clazz = dec.extendedType.declaration;
        buf.append(escaping.escapeName(clazz, unit))
            .append(".");
    }
    
    buf.append(escaping.escapeName(dec, unit));
    return buf.string;
}


// see CompletionUtil.overloads(Declaration dec)
shared {Declaration*} overloads(Declaration dec) {
    if (dec.abstraction) {
        //TODO: walk up the chain of refinedDeclarations
        if (exists refined = dec.overloads[0]?.refinedDeclaration, refined.overloaded,
            exists abstraction = refined.scope.getDirectMember(dec.name, null, false),
            abstraction.abstraction) {
            return { *dec.overloads }
                .chain { for (r in abstraction.overloads)
                         if (!any { for (d in dec.overloads) r==d.refinedDeclaration })
                         r };
        }
        else {
            return { *dec.overloads };
        }
    }
    else {
        //TODO: walk up the chain of refinedDeclarations
        if (exists refined = dec.refinedDeclaration, refined.overloaded,
            exists abstraction = refined.scope.getDirectMember(dec.name, null, false),
            abstraction.abstraction) {
            return { dec, for (r in abstraction.overloads) if (r!=refined) r };
        }
        else {
            return { dec };
        }
    }
}

// see CompletionUtil.getParameters
JList<Parameter> getParameters(ParameterList pl,
    Boolean includeDefaults, Boolean namedInvocation) {
    value ps = pl.parameters;
    if (includeDefaults) {
        return ps;
    }
    else {
        return Arrays.asList(
            for (p in ps)
            if (!p.defaulted
                || namedInvocation
                && spreadable(p, ps))
            p);
    }
}

Boolean spreadable(Parameter param, JList<Parameter> list) {
    if (exists lastParam = list[list.size()-1],
        param == lastParam,
        param.model is Value) {
        return if (exists type = param.type) 
            then param.declaration.unit
                .isIterableParameterType(type)
            else false;
    } else {
        return false;
    }
}


shared Boolean isModuleDescriptor(Tree.CompilationUnit? cu)
    => (cu?.unit?.filename else "") == "module.ceylon";

Boolean isPackageDescriptor(Tree.CompilationUnit? cu)
        => (cu?.unit?.filename else "") == "package.ceylon";

String getTextForDocLink(Unit? unit, Declaration decl) {
    String qname = decl.qualifiedNameString;
    
    if (exists pkg = decl.unit.\ipackage, 
        pkg.languagePackage
            || (if (exists unit) then pkg==unit.\ipackage else false)) {
        if (decl.toplevel) {
            return decl.nameAsString;
        } else {
            if (exists loc = qname.firstInclusion("::")) {
                return qname[loc+2...];
            } else {
                return qname;
            }
        }
    } else {
        return qname;
    }
}

Boolean isEmptyModuleDescriptor(Tree.CompilationUnit? cu) 
        => if (exists cu, isModuleDescriptor(cu))
        then cu.moduleDescriptors.empty
        else false;

Boolean isEmptyPackageDescriptor(Tree.CompilationUnit? cu) 
        => if (exists cu, isPackageDescriptor(cu))
        then cu.packageDescriptors.empty
        else false;

String fullPath(Integer offset, String prefix, Tree.ImportPath? path) {
    if (exists path) {
        value fullPath = TreeUtil.formatPath(path.identifiers) + ".";
        value maxLength = offset - path.startIndex.intValue() - prefix.size;
        return fullPath.initial(maxLength);
    }
    else {
        return "";
    }
}

Integer nextTokenType(LocalAnalysisResult cpc, CommonToken token) {
    variable Integer i = token.tokenIndex + 1;
    value tokens = cpc.tokens;
    while (exists tok = tokens[i]) {
        if (tok.channel != Token.hiddenChannel) {
            return tok.type;
        }
        i++;
    }
    return -1;
}

String getDefaultValueDescription(Parameter p, LocalAnalysisResult? cpc) 
        => if (p.defaulted) 
        then if (p.model is Functional)
            then " => ..."
            else getInitialValueDescription(p.model, cpc)
        else "";

shared String getInitialValueDescription(Declaration dec, LocalAnalysisResult? cpc) {
    if (exists cpc) {
        Tree.SpecifierOrInitializerExpression? sie;
        String arrow;
        switch (refnode = nodes.getReferencedNode(dec))
        case (is Tree.AttributeDeclaration) {
            sie = refnode.specifierOrInitializerExpression;
            arrow = " = ";
        }
        case (is Tree.MethodDeclaration) {
            sie = refnode.specifierExpression;
            arrow = " => ";
        }
        else {
            variable Tree.SpecifierOrInitializerExpression? result = null;
            object extends Visitor() {
                shared actual void visit(Tree.InitializerParameter that) {
                    super.visit(that);
                    if (exists d = that.parameterModel.model, d==dec) {
                        result = that.specifierExpression;
                    }
                }
            }.visit(cpc.lastCompilationUnit);
            sie = result;
            arrow = "";
        }

        switch (term = sie?.expression?.term)
        case (null) {
            return "";
        }
        case (is Tree.Literal) {
            value text = term.token.text;
            if (text.size < 20) {
                return arrow + text;
            }
        }
        case (is Tree.BaseMemberOrTypeExpression) {
            if (exists id = term.identifier,
                !exists b = term.typeArguments) {
                return arrow + id.text;
            }
        }
        else if (exists unit = cpc.lastCompilationUnit?.unit,
                    term.unit == unit) {
            value tokens = cpc.tokens;
            value impl = nodes.text(tokens, term);
            if (impl.size < 10) {
                return arrow + impl;
            }
        }
        return arrow + "...";
    }
    else {
        return "";
    }
}

String? getPackageName(Tree.CompilationUnit cu) 
        => if (is Package pack = cu.scope) 
            then pack.qualifiedNameString 
            else null;

shared Boolean isInBounds(JList<Type> upperBounds, Type type) {
    for (ub in upperBounds) {
        if (!type.isSubtypeOf(ub) &&
            !(ub.involvesTypeParameters() && 
              type.declaration.inherits(ub.declaration))) {
            return false;
        }
    }
    else {
        return true;
    }
}

Boolean withinBounds(Type requiredType, Type type, Scope scope) {
    value td = requiredType.resolveAliases().declaration;
    if (type.isSubtypeOf(requiredType)) {
        return true;
    }
    else if (is TypeParameter td) {
        return !td.isDefinedInScope(scope) && 
                isInBounds(td.satisfiedTypes, type);
    }
    else if (type.declaration.inherits(td)) {
        value supertype = type.getSupertype(td);
        for (tp in td.typeParameters) {
            if (exists ta = supertype.typeArguments[tp],
                exists rta = requiredType.typeArguments[tp]) {
                if (!withinBounds(rta, ta, scope)) {
                    return false;
                }
            }
            else {
                return false;
            }
        }
        else {
            return true;
        }
    }
    else {
        return false;
    }
}

void hackSortedResults(String? exactName, ArrayList<DeclarationWithProximity> results) {
    if (exists exactName) {
        //hack to take advantage of code in InvocationCompletion.addValueArgumentProposals
        for (i in 0:results.size()) {
            assert (exists dwp = results[i]);
            if (!dwp.unimported && !dwp.\ialias
                //if it matches the parameter name
                && ModelUtil.isNameMatching(dwp.name, exactName)) {
                //mess with its proximity
                results[i] = DeclarationWithProximity(dwp.declaration, -5);
            }
        }
    }
}

shared JList<DeclarationWithProximity> getSortedProposedValues(Scope scope, Unit unit,
        String? exactName = null, Cancellable? cancellable = null) {
    value map = scope.getMatchingDeclarations(unit, "", 0, cancellable);
    value results = ArrayList(map.values());
    Collections.sort(results, ArgumentProposalComparator(exactName));
    hackSortedResults(exactName, results);
    return results;
}

shared Boolean isIgnoredLanguageModuleClass(Class clazz)
        => clazz.isString()
        || clazz.integer
        || clazz.float
        || clazz.character
        || clazz.annotation;

shared Boolean isIgnoredLanguageModuleValue(Value val) {
    value name = val.name;
    return name == "process"
        || name == "runtime"
        || name == "system"
        || name == "operatingSystem"
        || name == "language"
        || name == "emptyIterator"
        || name == "infinity"
        || name == "IntegerValue"
        || name == "finished";
}

shared Boolean isIgnoredLanguageModuleMethod(Function method) {
    value name = method.name;
    return name == "className"
        || name == "flatten"
        || name == "unflatten"
        || name == "curry"
        || name == "uncurry"
        || name == "compose"
        || method.annotation;
}

Boolean isIgnoredLanguageModuleType(TypeDeclaration td)
        => !td.\iobject
        && !td.anything
        && !td.isString()
        && !td.integer
        && !td.character
        && !td.float
        && !td.boolean;

Integer findCharCount(Integer count, CommonDocument document, 
    Integer start, Integer end,
    String increments, String decrements, Boolean considerNesting) {

    assert (!(increments.empty && decrements.empty) && increments!=decrements);

    value none = 0;
    value bracket = 1;
    value brace = 2;
    value paren = 3;
    value angle = 4;

    variable value nestingMode = none;
    variable value nestingLevel = 0;

    variable value charCount = 0;
    variable value offset = start;
    variable value lastWasEquals = false;

    while (offset < end) {
        if (nestingLevel == 0) {
            if (count == charCount) {
                return offset - 1;
            }
        }
        value curr = document.getChar(offset++);
        switch (curr)
        case ('/') {
            if (offset < end) {
                value next = document.getChar(offset);
                if (next == '*') {
                    // a comment starts, advance to the comment end
                    // TODO offset = getCommentEnd(document, offset + 1, end);
                } else if (next == '/') {
                    // TODO
                    //value nextLine = document.getLineOfOffset(offset) + 1;
                    //if (nextLine == document.numberOfLines) {
                    //    offset = end;
                    //} else {
                    //    offset = document.getLineOffset(nextLine);
                    //}
                }
            }
        }
        case ('*') {
            if (offset < end) {
                value next = document.getChar(offset);
                if (next == '/') {
                    charCount = 0;
                    ++offset;
                }
            }
        }
        case ('"' | '\'') {
            // TODO offset = getStringEnd(document, offset, end, curr);
        }
        else {
            if (considerNesting) {
                switch (curr)
                case ('[') {
                    if (nestingMode==bracket || nestingMode==none) {
                        nestingMode = bracket;
                        nestingLevel++;
                    }
                }
                case (']') {
                    if (nestingMode == bracket && --nestingLevel == 0) {
                        nestingMode = none;
                    }
                }
                case ('(') {
                    if (nestingMode == angle) {
                        nestingMode = paren;
                        nestingLevel = 1;
                    }
                    if (nestingMode==paren || nestingMode==none) {
                        nestingMode = paren;
                        nestingLevel++;
                    }
                }            
                case (')') {
                    if (nestingMode == 0) {
                        return offset - 1;
                    }
                    if (nestingMode == paren) {
                        if (--nestingLevel == 0) {
                            nestingMode = none;
                        }
                    }
                }
                case ('{') {
                    if (nestingMode == angle) {
                        nestingMode = brace;
                        nestingLevel = 1;
                    }
                    if (nestingMode==brace || nestingMode==none) {
                        nestingMode = brace;
                        nestingLevel++;
                    }
                }
                case ('}') {
                    if (nestingMode == 0) {
                        return offset - 1;
                    }
                    if (nestingMode == brace && --nestingLevel == 0) {
                        nestingMode = none;
                    }
                }
                case ('<') {
                    if (nestingMode==angle || nestingMode==none) {
                        nestingMode = angle;
                        nestingLevel++;
                    }
                }
                else if (curr=='>' && !lastWasEquals) {
                    if (nestingMode == 0) {
                        return offset - 1;
                    }
                    if (nestingMode == angle) {
                        if (--nestingLevel == 0) {
                            nestingMode = none;
                        }
                    }
                }
                else if (nestingLevel == 0) {
                    if (curr in increments) {
                        ++charCount;
                    }
                    if (curr in decrements) {
                        --charCount;
                    }
                }
            }
            else {
                if (curr=='>' && !lastWasEquals && nestingMode == 0) {
                    return offset - 1;
                }
                if (nestingLevel == 0) {
                    if (curr in increments) {
                        ++charCount;
                    }
                    if (curr in decrements) {
                        --charCount;
                    }
                }
            }
        }
        lastWasEquals = curr == '=';
    }
    return -1;
}

shared String[] getAssignableLiterals(Type type, Unit unit) {
    value dtd = unit.getDefiniteType(type).declaration;
    if (is Class dtd) {
        if (dtd.integer) {
            return ["0", "1", "2"];
        }
        if (dtd.byte) {
            return ["0.byte", "1.byte"];
        } else if (dtd.float) {
            return ["0.0", "1.0", "2.0"];
        } else if (dtd.isString()) {
            return ["\"\"", "\"\"\"\"\"\""];
        } else if (dtd.character) {
            return ["''", "' '", "'\\n'", "'\\t'", "'.'", "'/'"];
        } else {
            return [];
        }
    } else if (is Interface dtd) {
        if (dtd.iterable) {
            return ["{}"];
        } else if (dtd.sequential || dtd.empty) {
            return ["[]"];
        } else {
            return [];
        }
    } else {
        return [];
    }
}


