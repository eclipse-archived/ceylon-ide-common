import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    escaping,
    OccurrenceLocation
}
import com.redhat.ceylon.model.typechecker.model {
    ModelUtil {
        ...
    },
    ...
}

import java.util {
    List,
    Collections
}
import com.redhat.ceylon.ide.common.platform {
    platformServices
}

Boolean forceExplicitTypeArgs(Declaration d, OccurrenceLocation? ol) {
    if (isLocation(ol, OccurrenceLocation.\iEXTENDS)) {
        return true;
    } else {
        //TODO: this is a pretty limited implementation 
        //      for now, but eventually we could do 
        //      something much more sophisticated to
        //      guess if explicit type args will be
        //      necessary (variance, etc)
        if (is Functional d) {
            value pls = d.parameterLists;
            return pls.empty || pls.get(0).parameters.empty;
        } else {
            return false;
        }
    }
}

shared String getTextFor(Declaration dec, Unit unit) {
    value result = StringBuilder();
    result.append(escaping.escapeName(dec, unit));
    appendTypeParameters(dec, result);
    return result.string;
}

String getPositionalInvocationTextFor(Declaration dec, OccurrenceLocation? ol,
    Reference pr, Unit unit, Boolean includeDefaulted, String? typeArgs,
    Boolean addParameterTypesInCompletions) {
    
    value result = StringBuilder().append(escaping.escapeName(dec, unit));
    
    if (exists typeArgs) {
        result.append(typeArgs);
    } else if (forceExplicitTypeArgs(dec, ol)) {
        appendTypeParameters(dec, result);
    }
    appendPositionalArgs(dec, pr, unit, result, includeDefaulted, false,
        addParameterTypesInCompletions);
    appendSemiToVoidInvocation(result, dec);
    return result.string;
}

String getNamedInvocationTextFor(Declaration dec, Reference pr, Unit unit, 
    Boolean includeDefaulted, String? typeArgs,
    Boolean addParameterTypesInCompletions) {
    
    value result = StringBuilder();
    result.append(escaping.escapeName(dec, unit));

    if (exists typeArgs) {
        result.append(typeArgs);
    } else if (forceExplicitTypeArgs(dec, null)) {
        appendTypeParameters(dec, result);
    }
    appendNamedArgs(dec, pr, unit, result, includeDefaulted, false,
        addParameterTypesInCompletions);
    appendSemiToVoidInvocation(result, dec);
    return result.string;
}

void appendSemiToVoidInvocation(StringBuilder result, Declaration dd) {
    if (is Function dd, dd.declaredVoid, dd.parameterLists.size() == 1) {
        result.append(";");
    }
}

shared String getDescriptionFor(Declaration dec, Unit unit) {
    value result = StringBuilder().append(dec.getName(unit));
    appendTypeParameters(dec, result);
    return result.string;
}

shared String getDescriptionFor2(DeclarationWithProximity dwp, Unit unit,
    Boolean addTypeParameters) {
    
    value result = StringBuilder();
    value dec = dwp.declaration;
    if (dwp.\ialias) {
        result.append(dwp.name);
        result.append(" \{#2192} ");
    }
    result.append(dec.getName(unit));
    if (addTypeParameters) {
        appendTypeParameters(dec, result);
    }
    return result.string;
}


shared String getPositionalInvocationDescriptionFor(
    DeclarationWithProximity? dwp, Declaration dec, OccurrenceLocation? ol,
    Reference pr, Unit unit, 
    Boolean includeDefaulted, 
    String? typeArgs, 
    Boolean addParameterTypesInCompletions) {
    
    value result = StringBuilder();
    if (exists dwp, dwp.\ialias) {
        result.append(dwp.name);
        result.append(" \{#2192} ");
    }
    result.append(dec.getName(unit));
    
    if (exists typeArgs) {
        result.append(typeArgs);
    } else if (forceExplicitTypeArgs(dec, ol)) {
        appendTypeParameters(dec, result);
    }
    appendPositionalArgs(dec, pr, unit, result, includeDefaulted, true,
        addParameterTypesInCompletions);
    return result.string;
}

shared String getNamedInvocationDescriptionFor(Declaration dec, Reference pr, 
        Unit unit, Boolean includeDefaulted, String? typeArgs,
        Boolean addParameterTypesInCompletions) {
    
    value result = StringBuilder();
    result.append(dec.getName(unit));
    
    if (exists typeArgs) {
        result.append(typeArgs);
    } else if (forceExplicitTypeArgs(dec, null)) {
        appendTypeParameters(dec, result);
    }
    appendNamedArgs(dec, pr, unit, result, includeDefaulted, true,
        addParameterTypesInCompletions);
    return result.string;
}

shared String getRefinementTextFor(Declaration d, Reference? pr, Unit unit,
    Boolean isInterface, ClassOrInterface? ci, String indent,   
    Boolean containsNewline, Boolean preamble,
    Boolean addParameterTypesInCompletions) {
    
    value result = StringBuilder();
    if (preamble) {
        result.append("shared actual ");
        if (isVariable(d), !isInterface) {
            result.append("variable ");
        }
    }
    appendDeclarationHeaderText(d, pr, unit, result);
    appendTypeParameters(d, result);
    appendParameters(d, pr, unit, result, null, false);
    if (is Class d) {
        result.append(extraIndent(extraIndent(indent, containsNewline), containsNewline))
                .append(" extends super.").append(escaping.escapeName(d));
        appendPositionalArgs(d, pr, unit, result, true, false,
            addParameterTypesInCompletions);
    }
    appendConstraints(d, pr, unit, indent, containsNewline, result);
    appendImplText(d, pr, isInterface, unit, indent, result, ci);
    return result.string;
}

void appendConstraints(Declaration d, Reference? pr, Unit unit, String indent,
    Boolean containsNewline, StringBuilder result) {
    
    if (is Generic d) {
        value generic = d;
        for (tp in generic.typeParameters) {
            value sts = tp.satisfiedTypes;
            if (!sts.empty) {
                result.append(extraIndent(extraIndent(indent, containsNewline), containsNewline))
                        .append("given ").append(tp.name).append(" satisfies ");
                variable Boolean first = true;
                for (st in sts) {
                    variable Type _st = st;
                    if (first) {
                        first = false;
                    } else {
                        result.append("&");
                    }
                    if (is Type pr) {
                        _st = st.substitute(pr);
                    } else {
                        assert (is TypedReference pr);
                        _st = st.substitute(pr);
                    }
                    result.append(_st.asSourceCodeString(unit));
                }
            }
        }
    }
}

shared String getInlineFunctionTextFor(Parameter p, Reference? pr, Unit unit,
    String indent) {
    
    value result = StringBuilder();
    appendNamedArgumentHeader(p, pr, result, false);
    appendTypeParameters(p.model, result);
    appendParametersText(p.model, pr, unit, result);
    if (p.declaredVoid) {
        result.append(" {}");
    } else {
        result.append(" => nothing;");
    }
    return result.string;
}

shared Boolean isVariable(Declaration d) {
    return if (is TypedDeclaration d, d.variable) then true else false;
}

String getRefinementDescriptionFor(Declaration d, Reference? pr, Unit unit) {
    value result = StringBuilder().append("shared actual ");
    
    if (isVariable(d)) {
        result.append("variable ");
    }
    appendDeclarationHeaderDescription(d, pr, unit, result);
    appendTypeParameters(d, result);
    appendParameters(d, pr, unit, result, null, true);
    /*result.append(" - refine declaration in ") 
        .append(((Declaration) d.getContainer()).getName());*/
    return result.string;
}

String getInlineFunctionDescriptionFor(Parameter p, Reference? pr, Unit unit) {
    value result = StringBuilder();
    appendNamedArgumentHeader(p, pr, result, true);
    appendTypeParameters(p.model, result);
    appendParameters(p.model, pr, unit, result, null, true);
    return result.string;
}

// see CodeCompletions.getDocDescriptionFor
shared String getDocDescriptionFor(Declaration decl,
    Reference? pr, Unit unit, LocalAnalysisResult cmp) {
    StringBuilder result = StringBuilder();
    appendDeclarationHeader(decl, pr, unit, result, true);
    appendTypeParametersWithArguments(decl, pr, unit, result, true);
    appendParametersDescription(decl, pr, unit, result, true, cmp);
    return result.string;
}

shared void appendPositionalArgs(Declaration d, Reference? pr, Unit unit,
    StringBuilder result, Boolean includeDefaulted, Boolean descriptionOnly,
    Boolean addParameterTypesInCompletions) {
    
    if (is Functional d) {
        value params = getParametersFunctional(d, includeDefaulted, false);
        if (params.empty) {
            result.append("()");
        } else if (exists pr) {
            value paramTypes = descriptionOnly && addParameterTypesInCompletions;
            result.append("(");
            for (p in params) {
                value typedParameter = pr.getTypedParameter(p);
                if (is Functional mod = p.model) {
                    if (p.declaredVoid) {
                        result.append("void ");
                    }
                    appendParameters(mod, typedParameter, unit, result, null,
                        descriptionOnly);
                    if (p.declaredVoid) {
                        result.append(" {}");
                    } else {
                        result.append(" => ").append("nothing");
                    }
                } else {
                    if (paramTypes, exists pt = typedParameter.type,
                        !isTypeUnknown(pt)) {
                        value newPt = if (p.sequenced)
                                      then unit.getSequentialElementType(pt)
                                      else pt;
                        result.append(newPt.asString(unit));
                        if (p.sequenced) {
                            result.append(if (p.atLeastOne) then "+" else "*");
                        }
                        result.append(" ");
                    } else if (p.sequenced) {
                        result.append("*");
                    }
                    FunctionOrValue? mod = p.model;
                    result.append(if (descriptionOnly || mod is Null)
                        then p.name else escaping.escapeName(p.model));
                }
                result.append(", ");
            }
            result.deleteTerminal(2);
            result.append(")");
        }
    }
}

void appendSuperArgsText(Declaration d, Reference? pr, Unit unit,
    StringBuilder result, Boolean includeDefaulted) {
    
    if (is Functional d) {
        value params = getParametersFunctional(d, includeDefaulted, false);
        if (params.empty) {
            result.append("()");
        } else {
            result.append("(");
            for (p in params) {
                if (p.sequenced) {
                    result.append("*");
                }
                result.append(escaping.escapeName(p.model)).append(", ");
            }
            result.deleteTerminal(2);
            result.append(")");
        }
    }
}

List<Parameter> getParametersFunctional(Functional fd, Boolean includeDefaults,
    Boolean namedInvocation) {
    
    List<ParameterList>? plists = fd.parameterLists;
    if (plists?.empty else true) {
        return Collections.emptyList<Parameter>();
    } else {
        assert (exists plists);
        return getParameters(plists.get(0), includeDefaults, namedInvocation);
    }
}

void appendNamedArgs(Declaration d, Reference pr, Unit unit, StringBuilder result,
    Boolean includeDefaulted, Boolean descriptionOnly,
    Boolean addParameterTypesInCompletions) {
    
    if (is Functional d) {
        value params = getParametersFunctional(d, includeDefaulted, true);
        if (params.empty) {
            result.append(" {}");
        } else {
            value paramTypes = 
                    descriptionOnly && 
                    addParameterTypesInCompletions;
            result.append(" { ");
            for (p in params) {
                value name = if (descriptionOnly)
                    then p.name
                    else escaping.escapeName(p.model);
                if (is Functional mod = p.model) {
                    if (p.declaredVoid) {
                        result.append("void ");
                    } else {
                        if (paramTypes, !isTypeUnknown(p.type)) {
                            value ptn = p.type.asString(unit);
                            result.append(ptn).append(" ");
                        } else {
                            result.append("function ");
                        }
                    }
                    result.append(name);
                    appendParameters(p.model, pr.getTypedParameter(p), unit,
                        result, null, descriptionOnly);
                    if (descriptionOnly) {
                        result.append("; ");
                    } else if (p.declaredVoid) {
                        result.append(" {} ");
                    } else {
                        result.append(" => ").append("nothing; ");
                    }
                } else {
                    if (p == params.get(params.size() - 1),
                        !isTypeUnknown(p.type),
                        unit.isIterableParameterType(p.type)) {
                        // nothing
                    } else {
                        if (paramTypes, !isTypeUnknown(p.type)) {
                            value ptn = p.type.asString(unit);
                            result.append(ptn).append(" ");
                        }
                        result.append(name).append(" = ")
                                .append("nothing").append("; ");
                    }
                }
            }
            result.append("}");
        }
    }
}

// see CodeCompletions.appendTypeParameters(Declaration d, StringBuilder result)
void appendTypeParameters(Declaration d, StringBuilder result,
    Boolean variances = false) {
    
    if (is Generic d) {
        value types = (d).typeParameters;
        if (!types.empty) {
            result.append("<");
            for (tp in types) {
                if (variances) {
                    if (tp.covariant) {
                        result.append("out ");
                    }
                    if (tp.contravariant) {
                        result.append("in ");
                    }
                }
                result.append(tp.name).append(", ");
            }
            result.deleteTerminal(2);
            result.append(">");
        }
    }
}

// see CodeCompletions.appendTypeParameters
shared void appendTypeParametersWithArguments(Declaration d, Reference? pr,
    Unit unit, StringBuilder result, Boolean variances) {
    
    if (is Generic d) {
        value types = d.typeParameters;
        
        if (!types.empty) {
            result.append("<");
            
            CeylonIterable(types).fold(true)((isFirst, tp) {
                if (!isFirst) { result.append(", "); }
                
                value arg = if (exists pr) then pr.typeArguments.get(tp) else null;
                
                if (!exists arg) {
                    if (variances) {
                        if (tp.covariant) {
                            result.append("out ");
                        } else if (tp.contravariant) {
                            result.append("in ");
                        }
                    }
                    result.append(tp.name);
                } else {
                    if (is Type pr, variances) {
                        if (exists variance = pr.varianceOverrides.get(tp)) {
                            if (variance == SiteVariance.\iOUT) {
                                result.append("out ");
                            } else if (variance == SiteVariance.\iIN) {
                                result.append("in ");
                            }
                        } else {
                            if (tp.covariant) {
                                result.append("out ");
                            } else if (tp.contravariant) {
                                result.append("in ");
                            }
                        }
                    }
                    result.append(arg.asString(unit));
                }
                
                return false;
            });
            
            result.append(">");
        }
    }
}

void appendDeclarationHeaderDescription(Declaration d, Reference? pr, Unit unit,
    StringBuilder result) {
    
    appendDeclarationHeader(d, pr, unit, result, true);
}

void appendDeclarationHeaderText(Declaration d, Reference? pr, Unit unit,
    StringBuilder result) {
    
    appendDeclarationHeader(d, pr, unit, result, false);
}

// see CodeCompletions.appendDeclarationHeader
void appendDeclarationHeader(Declaration decl, Reference? pr, Unit unit,
    StringBuilder builder, Boolean descriptionOnly) {
    
    if (is TypeAlias decl, decl.anonymous) {
        return;
    }
    
    if (isConstructor(decl)) {
        builder.append("new");
    } else {
        switch (decl)
        case (is Class) {
            builder.append(if (decl.anonymous) then "object" else "class");
        }
        case (is Interface) {
            builder.append("interface");
        }
        case (is TypeAlias) {
            builder.append("alias");
        }
        case (is TypedDeclaration) {
            value sequenced 
                    = if (is FunctionOrValue decl,
                        decl.parameter && decl.initializerParameter.sequenced)
            then true else false;
            
            variable Type? type 
                    = if (exists pr) then pr.type else decl.type;
            
            if (sequenced, exists t = type) {
//                type = unit.getIteratedType(type);
                //TODO: nasty workaround because unit can be null
                //      in docs for Open dialogs
                if (!t.typeArgumentList.empty) {
                    type = t.typeArgumentList.get(0);
                }
            }
            
            if (!exists t = type) {
                type = unit.unknownType;
            }
            
            assert (exists t = type);
            
            String typeName = if (descriptionOnly)
                then t.asString(unit)
                else t.asSourceCodeString(unit);
            
            if (decl.dynamicallyTyped) {
                builder.append("dynamic");
            } else if (is Value decl, t.declaration.anonymous, !t.typeConstructor) {
                builder.append("object");
            } else if (is Functional decl) {
                builder.append(if (decl.declaredVoid) then "void" else typeName);
            } else {
                builder.append(typeName);
            }
            
            if (sequenced) {
                builder.append(if (is FunctionOrValue decl,
                    decl.initializerParameter.atLeastOne) then "+" else "*");
            }
        }
        else {
        }
    }
    
    builder.append(" ");
    
    if (exists name = decl.name) {
        builder.append(if (descriptionOnly) then name else escaping.escapeName(decl));
    }
}


void appendNamedArgumentHeader(Parameter p, Reference? pr, StringBuilder result,
    Boolean descriptionOnly) {
    
    if (is Functional fp = p.model) {
        result.append(if (fp.declaredVoid) then "void" else "function");
    } else {
        result.append("value");
    }
    result.append(" ").append(if (descriptionOnly)
        then p.name else escaping.escapeName(p.model));
}

void appendImplText(Declaration d, Reference? pr, Boolean isInterface, Unit unit,
    String indent, StringBuilder result, ClassOrInterface? ci) {
    
    if (is Function d) {
        if (exists ci, !ci.anonymous) {
            if (d.name.equals("equals")) {
                value pl = (d).parameterLists;
                if (!pl.empty) {
                    value ps = pl.get(0).parameters;
                    if (!ps.empty) {
                        appendEqualsImpl(unit, indent, result, ci, ps);
                        return;
                    }
                }
            }
        }
        if (!d.formal) {
            result.append(" => super.").append(d.name);
            appendSuperArgsText(d, pr, unit, result, true);
            result.append(";");
        } else {
            if ((d).declaredVoid) {
                result.append(" {}");
            } else {
                result.append(" => nothing;");
            }
        }
    } else if (is Value d) {
        if (exists ci, !ci.anonymous) {
            if (d.name.equals("hash")) {
                appendHashImpl(unit, indent, result, ci);
                return;
            }
        }
        if (isInterface/*||d.isParameter()*/) {
            //interfaces can't have references,
            //so generate a setter for variables
            if (d.formal) {
                result.append(" => nothing;");
            } else {
                result.append(" => super.").append(d.name).append(";");
            }
            if (isVariable(d)) {
                result.append(indent).append("assign ").append(d.name).append(" {}");
            }
        } else {
            //we can have a references, so use = instead 
            //of => for variables
            value arrow = if (isVariable(d)) then " = " else " => ";
            if (d.formal) {
                result.append(arrow).append("nothing;");
            } else {
                result.append(arrow).append("super.").append(d.name).append(";");
            }
        }
    } else {
        //TODO: in the case of a class, formal member refinements!
        result.append(" {}");
    }
}

Value? getUniqueMemberForHash(Unit unit, ClassOrInterface ci) {
    variable Value? result = null;
    value nt = unit.nullValueDeclaration.type;
    for (m in ci.members) {
        if (is Value m, 
            !isObjectField(m) && !isConstructor(m),
            !m.transient && !nt.isSubtypeOf(m.type)) {
            if (result exists) {
                //not unique!
                return null;
            }
            else {
                result = m;
            }
        }
    }
    return result;
}

void appendHashImpl(Unit unit, String indent, StringBuilder result,
    ClassOrInterface ci) {
    
    if (exists v = getUniqueMemberForHash(unit, ci)) {
        result.append(" => ").append(v.name);
        if (!v.type.integer) {
            result.append(".hash");
        }
        result.append(";");
    }
    else {
        value defaultIndent = platformServices.document.defaultIndent;
        result.append(" {")
                .append(indent)
                .append(defaultIndent)
                .append("variable value hash = 1;")
                .append(indent)
                .append(defaultIndent);
        
        value ind = indent + defaultIndent;
        appendMembersToHash(unit, ind, result, ci);
        result.append("return hash;").append(indent).append("}");
    }
}

void appendEqualsImpl(Unit unit, String indent, StringBuilder result,
    ClassOrInterface ci, List<Parameter> ps) {
    
    value targs = StringBuilder();
    if (!ci.typeParameters.empty) {
        targs.append("<");
        for (tp in ci.typeParameters) {
            if (targs.longerThan(1)) {
                targs.append(",");
            }
            String bounds = 
                    unit.denotableType(intersectionOfSupertypes(tp))
                        .asSourceCodeString(unit);
            if (tp.covariant) {
                targs.append(bounds);
            }
            else if (tp.contravariant) {
                targs.append("Nothing");
            }
            else {
                targs.append("out ").append(bounds);
            }
        }
        targs.append(">");
    }
    
    value p = ps.get(0);
    value defaultIndent = platformServices.document.defaultIndent;
    result.append(" {")
            .append(indent).append(defaultIndent)
            .append("if (is ").append(ci.name).append(targs.string).append(" ").append(p.name).append(") {")
            .append(indent).append(defaultIndent).append(defaultIndent)
            .append("return ");
    
    value ind = indent + defaultIndent + defaultIndent
            + defaultIndent;
    appendMembersToEquals(unit, ind, result, ci, p);
    result.append(indent).append(defaultIndent)
            .append("}")
            .append(indent).append(defaultIndent)
            .append("else {")
            .append(indent).append(defaultIndent).append(defaultIndent)
            .append("return false;").append(indent)
            .append(defaultIndent)
            .append("}")
            .append(indent)
            .append("}");
}

Boolean isObjectField(Declaration m) {
    String? name = m.name;
    return if (exists name, (name.equals("hash") || name.equals("string")))
    then true else false;
}

void appendMembersToEquals(Unit unit, String indent, StringBuilder result,
    ClassOrInterface ci, Parameter p) {
    
    variable value found = false;
    value nt = unit.nullValueDeclaration.type;
    for (m in ci.members) {
        if (is Value m, 
            !isObjectField(m), !isConstructor(m), 
            !m.transient, !nt.isSubtypeOf(m.type)) {
            if (found) {
                result.append(" && ").append(indent);
            }
            result.append(m.name).append("==")
                    .append(p.name).append(".").append(m.name);
            found = true;
        }
    }
    if (found) {
        result.append(";");
    } else {
        result.append("true;");
    }
}

void appendMembersToHash(Unit unit, String indent, StringBuilder result,
    ClassOrInterface ci) {
    
    value nt = unit.nullValueDeclaration.type;
    for (m in ci.members) {
        if (is Value m, 
            !isObjectField(m), !isConstructor(m),
            !m.transient, !nt.isSubtypeOf(m.type)) {
            result.append("hash = 31*hash + ").append(m.name);
            if (!m.type.integer) {
                result.append(".hash");
            }
            result.append(";").append(indent);
        }
    }
}

String extraIndent(String indent, Boolean containsNewline) 
        => if (containsNewline) then indent + platformServices.document.defaultIndent else indent;

shared void appendParametersText(Declaration d, Reference? pr, Unit unit,
    StringBuilder result) {
    appendParameters(d, pr, unit, result, null, false);
}

void appendParameters(Declaration d, Reference? pr,
    Unit unit, StringBuilder result, LocalAnalysisResult? cpc,
    Boolean descriptionOnly) {
    if (is Functional d) {
        if (exists plists = d.parameterLists) {
            for (params in plists) {
                if (params.parameters.empty) {
                    result.append("()");
                } else {
                    result.append("(");
                    for (p in params.parameters) {
                        appendParameter(result, pr, p, unit, descriptionOnly);
                        if (exists cpc) {
                            result.append(getDefaultValueDescription(p, cpc));
                        }
                        result.append(", ");
                    }
                    result.deleteTerminal(2);
                    result.append(")");
                }
            }
        }
    }
}

shared void appendParameter(StringBuilder result, Reference? pr, Parameter p,
    Unit unit, Boolean descriptionOnly) {
    
    if (!exists mod = p.model) {
        result.append(p.name);
    } else {
        value ppr = if (!exists pr) then null else pr.getTypedParameter(p);
        appendDeclarationHeader(p.model, ppr, unit, result, descriptionOnly);
        appendParameters(p.model, ppr, unit, result, null, descriptionOnly);
    }
}


// see CodeCompletions.appendParametersDescription
void appendParametersDescription(Declaration d,
    Reference? pr, Unit unit, StringBuilder result, Boolean descriptionOnly,
    LocalAnalysisResult cmp) {
    
    appendParameters(d, pr, d.unit, result, cmp, descriptionOnly);
}
