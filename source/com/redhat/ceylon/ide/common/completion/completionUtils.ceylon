import ceylon.interop.java {
    CeylonIterable,
    javaString
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    TreeUtil,
    Visitor
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation,
    nodes,
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Parameter,
    ParameterList,
    Value,
    Unit,
    Declaration,
    Package,
    Module,
    Functional,
    DeclarationWithProximity,
    Scope,
    Function,
    Class,
    Type,
    TypeDeclaration,
    Interface,
    ModelUtil,
    Constructor
}

import java.lang {
    JCharacter=Character
}
import java.util {
    List,
    ArrayList,
    Collections
}

import org.antlr.runtime {
    CommonToken
}

shared Boolean isLocation(OccurrenceLocation? loc1, OccurrenceLocation loc2) {
    if (exists loc1) {
        return loc1 == loc2;
    }
    return false;
}

shared String anonFunctionHeader(Type? requiredType, Unit unit) {
    value text = StringBuilder();
    text.append("(");
    
    variable Character c = 'a';
    
    CeylonIterable(unit.getCallableArgumentTypes(requiredType)).fold(true)((isFirst, paramType) {
        if (!isFirst) { text.append(", "); }
        text.append(paramType.asSourceCodeString(unit))
                .append(" ")
                .append(c.string);
        c++;
        
        return false;
    });
    text.append(")");
    
    return text.string;
}

shared String getProposedName(Declaration? qualifier, Declaration dec, Unit unit) {
    value buf = StringBuilder();
    if (exists qualifier) {
        buf.append(escaping.escapeName(qualifier, unit)).append(".");
    }
    
    if (is Constructor dec) {
        value constructor = dec;
        value clazz = constructor.extendedType.declaration;
        buf.append(escaping.escapeName(clazz, unit)).append(".");
    }
    
    buf.append(escaping.escapeName(dec, unit));
    return buf.string;
}


// see CompletionUtil.overloads(Declaration dec)
shared {Declaration*} overloads(Declaration dec) {
    return if (dec.abstraction)
    then CeylonIterable(dec.overloads)
    else {dec};
}

// see CompletionUtil.getParameters
List<Parameter> getParameters(ParameterList pl,
    Boolean includeDefaults, Boolean namedInvocation) {
    List<Parameter> ps = pl.parameters;
    if (includeDefaults) {
        return ps;
    }
    else {
        List<Parameter> list = ArrayList<Parameter>();
        for (p in ps) {
            if (!p.defaulted || 
                (namedInvocation && spreadable(p, ps))) {
                list.add(p);
            }
        }
        return list;
    }
}

Boolean spreadable(Parameter param, List<Parameter> list) {
    value lastParam = list.get(list.size() - 1);
    if (param == lastParam, param.model is Value) {
        Type? type = param.type;
        value unit = param.declaration.unit;
        return type exists && unit.isIterableParameterType(type);
    } else {
        return false;
    }
}


shared Boolean isModuleDescriptor(Tree.CompilationUnit? cu)
    => (cu?.unit?.filename else "") == "module.ceylon";

Boolean isPackageDescriptor(Tree.CompilationUnit? cu)
        => (cu?.unit?.filename else "") == "package.ceylon";

String getTextForDocLink(Unit? unit, Declaration decl) {
    Package? pkg = decl.unit.\ipackage;
    String qname = decl.qualifiedNameString;
    
    if (exists pkg, (Module.\iLANGUAGE_MODULE_NAME.equals(pkg.nameAsString) || (if (exists unit) then pkg.equals(unit.\ipackage) else false))) {
        if (decl.toplevel) {
            return decl.nameAsString;
        } else {
            if (exists loc = qname.firstInclusion("::")) {
                return qname.spanFrom(loc + 2);
            } else {
                return qname;
            }
        }
    } else {
        return qname;
    }
}

Boolean isEmptyModuleDescriptor(Tree.CompilationUnit? cu) 
        => if (isModuleDescriptor(cu), exists cu, cu.moduleDescriptors.empty) 
            then true else false;

Boolean isEmptyPackageDescriptor(Tree.CompilationUnit? cu) 
        => if (exists cu, 
               exists u = cu.unit,
               u.filename == "package.ceylon",
               cu.packageDescriptors.empty) 
            then true else false;

String fullPath(Integer offset, String prefix, Tree.ImportPath? path) {
    StringBuilder fullPath = StringBuilder();
    
    if (exists path) {
        fullPath.append(TreeUtil.formatPath(path.identifiers));
        fullPath.append(".");
        value maxLength = offset - path.startIndex.intValue() - prefix.size;
        return fullPath.substring(0, maxLength);
    }
    return fullPath.string;
}

Integer nextTokenType<Document>(LocalAnalysisResult<Document> cpc, CommonToken token) {
    variable Integer i = token.tokenIndex + 1;
    assert(exists tokens = cpc.tokens);
    while (i < tokens.size()) {
        CommonToken tok = tokens.get(i);
        if (tok.channel != CommonToken.\iHIDDEN_CHANNEL) {
            return tok.type;
        }
        i++;
    }
    return -1;
}

String getDefaultValueDescription<Document>(Parameter p, LocalAnalysisResult<Document>? cpc) {
    if (p.defaulted) {
        if (is Functional m = p.model) {
            return " => ...";
        } else {
            return getInitialValueDescription(p.model, cpc);
        }
    } else {
        return "";
    }
}

shared String getInitialValueDescription<Document>(Declaration dec, LocalAnalysisResult<Document>? cpc) {
    if (exists cpc) {
        variable Tree.SpecifierOrInitializerExpression? sie = null;
        variable String arrow = "";
        switch (refnode = nodes.getReferencedNode(dec))
        case (is Tree.AttributeDeclaration) {
            value ad = refnode;
            sie = ad.specifierOrInitializerExpression;
            arrow = " = ";
        }
        case (is Tree.MethodDeclaration) {
            value md = refnode;
            sie = md.specifierExpression;
            arrow = " => ";
        }
        else {}
        if (!exists s = sie) {
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
        }
        if (exists term = sie?.expression?.term) {
            switch (term)
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
            else if (exists tokens = cpc.tokens, 
                    term.unit == cpc.lastCompilationUnit.unit) {
                value impl = nodes.text(term, tokens);
                if (impl.size < 10) {
                    return arrow + impl;
                }
            }
            //don't have the token stream :-/
            //TODO: figure out where to get it from!
            return arrow + "...";
        }
    }
    return "";
}

String? getPackageName(Tree.CompilationUnit cu) 
        => if (is Package pack = cu.scope) 
            then pack.qualifiedNameString 
            else null;

shared Boolean isInBounds(List<Type> upperBounds, Type t) {
    for (ub in upperBounds) {
        if (!t.isSubtypeOf(ub) &&
            !(ub.involvesTypeParameters() && 
              t.declaration.inherits(ub.declaration))) {
            return false;
        }
    }
    else {
        return true;
    }
}


shared List<DeclarationWithProximity> getSortedProposedValues(Scope scope, Unit unit, String? exactName = null) {
    value map = scope.getMatchingDeclarations(unit, "", 0, null);
    if (exists exactName) {
        for (dwp in ArrayList(map.values())) {
            if (!dwp.unimported, !dwp.\ialias,
                ModelUtil.isNameMatching(dwp.name, exactName)) {
                
                map.put(javaString(dwp.name), DeclarationWithProximity(dwp.declaration, -5));
            }
        }
    }
    value results = ArrayList(map.values());
    Collections.sort(results, ArgumentProposalComparator(exactName));
    return results;
}

shared Boolean isIgnoredLanguageModuleClass(Class clazz) {
    return clazz.isString()
            || clazz.integer
            || clazz.float
            || clazz.character
            || clazz.annotation;
}

shared Boolean isIgnoredLanguageModuleValue(Value \ivalue) {
    value name = \ivalue.name;
    return name.equals("process")
            || name.equals("runtime") 
            || name.equals("system") 
            || name.equals("operatingSystem") 
            || name.equals("language") 
            || name.equals("emptyIterator") 
            || name.equals("infinity") 
            || name.endsWith("IntegerValue") 
            || name.equals("finished");
}

shared Boolean isIgnoredLanguageModuleMethod(Function method) {
    value name = method.name;
    return name.equals("className") 
            || name.equals("flatten") 
            || name.equals("unflatten") 
            || name.equals("curry") 
            || name.equals("uncurry") 
            || name.equals("compose") 
            || method.annotation;
}

Boolean isIgnoredLanguageModuleType(TypeDeclaration td) {
    return !td.\iobject 
            && !td.anything 
            && !td.isString() 
            && !td.integer 
            && !td.character 
            && !td.float 
            && !td.boolean;
}

Integer findCharCount<Document>(Integer count, Document document, Integer start, Integer end,
    String increments, String decrements, Boolean considerNesting, JCharacter(Document,Integer) getChar) {

    assert((!increments.empty || !decrements.empty) && !increments.equals(decrements));

    value \iNONE = 0;
    value \iBRACKET = 1;
    value \iBRACE = 2;
    value \iPAREN = 3;
    value \iANGLE = 4;

    variable value nestingMode = \iNONE;
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
        value curr = getChar(document, offset++).charValue();
        switch (curr)
        case ('/') {
            if (offset < end) {
                value next = getChar(document, offset);
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
                value next = getChar(document, offset);
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
                    if (nestingMode==\iBRACKET || nestingMode==\iNONE) {
                        nestingMode = \iBRACKET;
                        nestingLevel++;
                    }
                }
                case (']') {
                    if (nestingMode == \iBRACKET && --nestingLevel == 0) {
                        nestingMode = \iNONE;
                    }
                }
                case ('(') {
                    if (nestingMode == \iANGLE) {
                        nestingMode = \iPAREN;
                        nestingLevel = 1;
                    }
                    if (nestingMode==\iPAREN || nestingMode==\iNONE) {
                        nestingMode = \iPAREN;
                        nestingLevel++;
                    }
                }            
                case (')') {
                    if (nestingMode == 0) {
                        return offset - 1;
                    }
                    if (nestingMode == \iPAREN) {
                        if (--nestingLevel == 0) {
                            nestingMode = \iNONE;
                        }
                    }
                }
                case ('{') {
                    if (nestingMode == \iANGLE) {
                        nestingMode = \iBRACE;
                        nestingLevel = 1;
                    }
                    if (nestingMode==\iBRACE || nestingMode==\iNONE) {
                        nestingMode = \iBRACE;
                        nestingLevel++;
                    }
                }
                case ('}') {
                    if (nestingMode == 0) {
                        return offset - 1;
                    }
                    if (nestingMode == \iBRACE && --nestingLevel == 0) {
                        nestingMode = \iNONE;
                    }
                }
                case ('<') {
                    if (nestingMode==\iANGLE || nestingMode==\iNONE) {
                        nestingMode = \iANGLE;
                        nestingLevel++;
                    }
                }
                else if (curr=='>' && !lastWasEquals) {
                    if (nestingMode == 0) {
                        return offset - 1;
                    }
                    if (nestingMode == \iANGLE) {
                        if (--nestingLevel == 0) {
                            nestingMode = \iNONE;
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
            return ["' '", "'\\n'", "'\\t'"];
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


