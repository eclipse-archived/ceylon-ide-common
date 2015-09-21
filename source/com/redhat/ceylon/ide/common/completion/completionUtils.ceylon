import com.redhat.ceylon.ide.common.util {
    OccurrenceLocation,
    nodes
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
    FunctionOrValue,
    DeclarationWithProximity,
    Scope,
    Function,
    Class,
    Type,
    TypeDeclaration
}
import java.util {
    List,
    ArrayList,
    Collections,
    Comparator
}
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
import org.antlr.runtime {
    CommonToken
}
import java.lang {
    JCharacter=Character
}

Boolean isLocation(OccurrenceLocation? loc1, OccurrenceLocation loc2) {
    if (exists loc1) {
        return loc1 == loc2;
    }
    return false;
}

// see CompletionUtil.overloads(Declaration dec)
{Declaration*} overloads(Declaration dec) {
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
        for (p in CeylonIterable(ps)) {
            if (!p.defaulted || 
                (namedInvocation && 
                p==ps.get(ps.size()-1) && 
                    p.model is Value &&
                    p.type exists &&
                    p.declaration.unit
                    .isIterableParameterType(p.type))) {
                list.add(p);
            }
        }
        return list;
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

Boolean isEmptyModuleDescriptor(Tree.CompilationUnit? cu) {
    return if (isModuleDescriptor(cu), exists cu, cu.moduleDescriptors.empty) then true else false;
}

Boolean isEmptyPackageDescriptor(Tree.CompilationUnit? cu) {
    return if (exists cu, 
               exists u = cu.unit,
               u.filename == "package.ceylon",
               cu.packageDescriptors.empty) then true else false; 
}

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

Integer nextTokenType<Document,IdeArtifact>(LocalAnalysisResult<Document,IdeArtifact> cpc, CommonToken token) {
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

String getDefaultValueDescription<Document,IdeArtifact>(Parameter p, LocalAnalysisResult<Document,IdeArtifact>? cpc) {
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

shared String getInitialValueDescription<Document,IdeArtifact>(Declaration dec, LocalAnalysisResult<Document,IdeArtifact>? cpc) {
    if (exists cpc) {
        value refnode = nodes.getReferencedNode(dec);
        variable Tree.SpecifierOrInitializerExpression? sie = null;
        variable String arrow = "";
        if (is Tree.AttributeDeclaration refnode) {
            value ad = refnode;
            sie = ad.specifierOrInitializerExpression;
            arrow = " = ";
        } else if (is Tree.MethodDeclaration refnode) {
            value md = refnode;
            sie = md.specifierExpression;
            arrow = " => ";
        }
        if (!exists s = sie) {
            class FindInitializerVisitor() extends Visitor() {
                shared variable Tree.SpecifierOrInitializerExpression? result = null;
                
                shared actual void visit(Tree.InitializerParameter that) {
                    super.visit(that);
                    FunctionOrValue? d = that.parameterModel.model;
                    if (exists d, d.equals(dec)) {
                        result = that.specifierExpression;
                    }
                }
            }
            value fiv = FindInitializerVisitor();
            (fiv of Visitor).visit(cpc.rootNode);
            sie = fiv.result;
        }
        if (exists s = sie) {
            Tree.Expression? e = s.expression;
            if (exists e) {
                value term = e.term;
                if (is Tree.Literal term) {
                    value text = term.token.text;
                    if (text.size < 20) {
                        return arrow + text;
                    }
                } else if (is Tree.BaseMemberOrTypeExpression term) {
                    value bme = term;
                    Tree.Identifier? id = bme.identifier;
                    if (exists id, !exists b = bme.typeArguments) {
                        return arrow + id.text;
                    }
                } else if (term.unit.equals(cpc.rootNode.unit)) {
                    value impl = nodes.toString(term, cpc.tokens);
                    if (impl.size < 10) {
                        return arrow + impl;
                    }
                }
                //don't have the token stream :-/
                //TODO: figure out where to get it from!
                return arrow + "...";
            }
        }
    }
    return "";
}

String? getPackageName(Tree.CompilationUnit cu) {
    if (is Package pack = cu.scope) {
        return pack.qualifiedNameString;
    }
    return null;
}

shared Boolean isInBounds(List<Type> upperBounds, Type t) {
    variable value ok = true;
    for (ub in CeylonIterable(upperBounds)) {
        if (!t.isSubtypeOf(ub), !(ub.involvesTypeParameters() && t.declaration.inherits(ub.declaration))) {
            ok = false;
            break;
        }
    }
    return ok;
}


shared List<DeclarationWithProximity> getSortedProposedValues(Scope scope, Unit unit) {
    value results = ArrayList<DeclarationWithProximity>(scope.getMatchingDeclarations(unit, "", 0).values());
    Collections.sort(results, object satisfies Comparator<DeclarationWithProximity> {
            shared actual Integer compare(DeclarationWithProximity x, DeclarationWithProximity y) {
                if (x.proximity < y.proximity) {
                    return -1;
                }
                if (x.proximity > y.proximity) {
                    return 1;
                }
                value c = javaString(x.declaration.name).compareTo(y.declaration.name);
                if (c != 0) {
                    return c;
                }
                return javaString(x.declaration.qualifiedNameString).compareTo(y.declaration.qualifiedNameString);
            }
            
            shared actual Boolean equals(Object that) => false;
        }
    );
    return results;
}

shared Boolean isIgnoredLanguageModuleClass(Class clazz) {
    value name = clazz.name;
    return name.equals("String")
            || name.equals("Integer")
            || name.equals("Float")
            || name.equals("Character")
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
    value name = td.name;
    return !name.equals("Object") 
            && !name.equals("Anything") 
            && !name.equals("String") 
            && !name.equals("Integer") 
            && !name.equals("Character") 
            && !name.equals("Float") 
            && !name.equals("Boolean");
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
        value curr = getChar(document, offset++);
        switch (curr.charValue())
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
        case ('"') {
            // TODO offset = getStringEnd(document, offset, end, curr);
        }
        case ('[') {
            if (considerNesting) {
                if (nestingMode==\iBRACKET || nestingMode==\iNONE) {
                    nestingMode = \iBRACKET;
                    nestingLevel++;
                }
                break;
            }
        }
        case (']') {
            if (considerNesting) {
                if (nestingMode == \iBRACKET) {
                    if (--nestingLevel == 0) {
                        nestingMode = \iNONE;
                    }
                }
                break;
            }
        }
        case ('(') {
            if (considerNesting) {
                if (nestingMode == \iANGLE) {
                    nestingMode = \iPAREN;
                    nestingLevel = 1;
                }
                if (nestingMode==\iPAREN || nestingMode==\iNONE) {
                    nestingMode = \iPAREN;
                    nestingLevel++;
                }
                break;
            }
        }
        case (')') {
            if (considerNesting) {
                if (nestingMode == 0) {
                    return offset - 1;
                }
                if (nestingMode == \iPAREN) {
                    if (--nestingLevel == 0) {
                        nestingMode = \iNONE;
                    }
                }
                break;
            }
        }
        case ('{') {
            if (considerNesting) {
                if (nestingMode == \iANGLE) {
                    nestingMode = \iBRACE;
                    nestingLevel = 1;
                }
                if (nestingMode==\iBRACE || nestingMode==\iNONE) {
                    nestingMode = \iBRACE;
                    nestingLevel++;
                }
                break;
            }
        }
        case ('}') {
            if (considerNesting) {
                if (nestingMode == 0) {
                    return offset - 1;
                }
                if (nestingMode == \iBRACE) {
                    if (--nestingLevel == 0) {
                        nestingMode = \iNONE;
                    }
                }
                break;
            }
        }
        case ('<') {
            if (considerNesting) {
                if (nestingMode==\iANGLE || nestingMode==\iNONE) {
                    nestingMode = \iANGLE;
                    nestingLevel++;
                }
                break;
            }
        }
        case ('>') {
            if (!lastWasEquals) {
                if (nestingMode == 0) {
                    return offset - 1;
                }
                if (considerNesting) {
                    if (nestingMode == \iANGLE) {
                        if (--nestingLevel == 0) {
                            nestingMode = \iNONE;
                        }
                    }
                    break;
                }
            }
        }
        else {
            if (nestingLevel == 0) {
                if (increments.firstOccurrence(curr.charValue()) exists) {
                    ++charCount;
                }
                if (decrements.firstOccurrence(curr.charValue()) exists) {
                    --charCount;
                }
            }
        }
        lastWasEquals = curr == '=';
    }
    return -1;
}


