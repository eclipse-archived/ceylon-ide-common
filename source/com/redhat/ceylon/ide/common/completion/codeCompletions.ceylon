import com.redhat.ceylon.ide.common.platform {
    platformServices
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
            return
                if (exists pl = d.parameterLists[0])
                then pl.parameters.empty
                else true;
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
    Reference pr, Unit unit, Boolean includeDefaulted, String? typeArgs) {
    
    value result 
            = StringBuilder()
                .append(escaping.escapeName(dec, unit));
    
    if (exists typeArgs) {
        result.append(typeArgs);
    } else if (forceExplicitTypeArgs(dec, ol)) {
        appendTypeParameters(dec, result);
    }
    appendPositionalArgs {
        d = dec;
        pr = pr;
        unit = unit;
        result = result;
        includeDefaulted = includeDefaulted;
        descriptionOnly = false;
        addParameterTypesInCompletions = false;
    };
    appendSemiToVoidInvocation(result, dec);
    return result.string;
}

String getNamedInvocationTextFor(Declaration dec, Reference pr, Unit unit, 
    Boolean includeDefaulted, String? typeArgs) {
    
    value result = StringBuilder();
    result.append(escaping.escapeName(dec, unit));

    if (exists typeArgs) {
        result.append(typeArgs);
    } else if (forceExplicitTypeArgs(dec, null)) {
        appendTypeParameters(dec, result);
    }
    appendNamedArgs {
        d = dec;
        pr = pr;
        unit = unit;
        result = result;
        includeDefaulted = includeDefaulted;
        descriptionOnly = false;
        addParameterTypesInCompletions = false;
    };
    appendSemiToVoidInvocation(result, dec);
    return result.string;
}

void appendSemiToVoidInvocation(StringBuilder result, 
        Declaration declaration) {
    if (is Function declaration, declaration.declaredVoid, 
        declaration.parameterLists.size() == 1) {
        result.append(";");
    }
}

shared String getDescriptionFor(Declaration dec, Unit unit) {
    value result = StringBuilder().append(dec.getName(unit));
    appendTypeParameters(dec, result);
    return result.string;
}

shared String getDescriptionFor2(DeclarationWithProximity dwp, 
    Unit unit, Boolean addTypeParameters) {
    
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
    DeclarationWithProximity? dwp, Declaration dec, 
    OccurrenceLocation? ol,
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

    for (tp in d.typeParameters) {
        value sts = tp.satisfiedTypes;
        if (!sts.empty) {
            result.append(extraIndent(extraIndent(indent, containsNewline), containsNewline))
                    .append("given ").append(tp.name).append(" satisfies ");
            variable value first = true;
            for (st in sts) {
                if (first) {
                    first = false;
                }
                else {
                    result.append("&");
                }
                Type t;
                switch (pr)
                case (is Type) {
                    t = st.substitute(pr);
                }
                case (is TypedReference) {
                    t = st.substitute(pr);
                }
                else {
                    assert (false);
                }
                result.append(t.asSourceCodeString(unit));
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

shared Boolean isVariable(Declaration d) 
        => if (is TypedDeclaration d) then d.variable else false;

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
    Reference? pr, Unit unit, LocalAnalysisResult? cmp) {
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
        value params = getParametersFunctional {
            fd = d;
            includeDefaults = includeDefaulted;
            namedInvocation = false;
        };
        if (params.empty) {
            result.append("()");
        }
        else if (exists pr) {
            value paramTypes 
                    = descriptionOnly 
                    && addParameterTypesInCompletions;
            result.append("(");
            for (p in params) {
                value typedParameter = pr.getTypedParameter(p);
                /*if (is Functional mod = p.model) {
                    if (p.declaredVoid) {
                        result.append("void ");
                    }
                    appendParameters {
                        d = mod;
                        pr = typedParameter;
                        unit = unit;
                        result = result;
                        cpc = null;
                        descriptionOnly = descriptionOnly;
                    };
                    if (p.declaredVoid) {
                        result.append(" {}");
                    }
                    else {
                        result.append(" => ").append("nothing");
                    }
                }
                else {*/
                    if (paramTypes, 
                        exists pt = typedParameter.fullType,
                        !isTypeUnknown(pt)) {
                        value newPt
                                = p.sequenced
                                then unit.getSequentialElementType(pt)
                                else pt;
                        result.append(newPt.asString(unit));
                        if (p.sequenced) {
                            result.append(p.atLeastOne then "+" else "*");
                        }
                        result.append(" ");
                    }
                    else if (p.sequenced) {
                        result.append("*");
                    }
                    if (!descriptionOnly, 
                        exists mod = p.model, 
                        mod.name exists) {
                        result.append(escaping.escapeName(mod));
                    }
                    else if (exists name = p.name) {
                        result.append(name);
                    }
//                }
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
        value params = getParametersFunctional {
            fd = d;
            includeDefaults = includeDefaulted;
            namedInvocation = false;
        };
        if (params.empty) {
            result.append("()");
        } else {
            result.append("(");
            for (p in params) {
                if (p.sequenced) {
                    result.append("*");
                }
                result.append(escaping.escapeName(p.model))
                    .append(", ");
            }
            result.deleteTerminal(2);
            result.append(")");
        }
    }
}

List<Parameter> getParametersFunctional(Functional fd, 
    Boolean includeDefaults, Boolean namedInvocation) {

    if (exists plists = fd.parameterLists,
        exists plist = plists[0]) {
        return getParameters {
            pl = plist;
            includeDefaults = includeDefaults;
            namedInvocation = namedInvocation;
        };
    } else {
        return Collections.emptyList<Parameter>();
    }
}

void appendNamedArgs(Declaration d, Reference pr, Unit unit, 
    StringBuilder result,
    Boolean includeDefaulted, Boolean descriptionOnly,
    Boolean addParameterTypesInCompletions) {
    
    if (is Functional d) {
        value params = getParametersFunctional {
            fd = d;
            includeDefaults = includeDefaulted;
            namedInvocation = true;
        };
        if (params.empty) {
            result.append(" {}");
        }
        else {
            value paramTypes = 
                    descriptionOnly && 
                    addParameterTypesInCompletions;
            result.append(" { ");
            for (p in params) {
                value name
                        = descriptionOnly
                        then (p.name else "")
                        else escaping.escapeName(p.model);
                if (is Functional mod = p.model) {
                    if (p.declaredVoid) {
                        result.append("void ");
                    }
                    else {
                        if (paramTypes, !isTypeUnknown(p.type)) {
                            value ptn = p.type.asString(unit);
                            result.append(ptn).append(" ");
                        }
                        else {
                            result.append("function ");
                        }
                    }
                    result.append(name);
                    appendParameters {
                        d = p.model;
                        pr = pr.getTypedParameter(p);
                        unit = unit;
                        result = result;
                        cpc = null;
                        descriptionOnly = descriptionOnly;
                    };
                    if (descriptionOnly) {
                        result.append("; ");
                    }
                    else if (p.declaredVoid) {
                        result.append(" {} ");
                    }
                    else {
                        result.append(" => nothing; ");
                    }
                }
                else {
                    if (p == params.get(params.size() - 1),
                        !isTypeUnknown(p.type),
                        unit.isIterableParameterType(p.type)) {
                        // nothing
                    }
                    else {
                        if (paramTypes, !isTypeUnknown(p.type)) {
                            value ptn = p.type.asString(unit);
                            result.append(ptn).append(" ");
                        }
                        result.append(name);
                        if (!descriptionOnly) {
                            result.append(" = nothing");
                        }
                        result.append("; ");
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
    
    if (d.parameterized) {
        value types = d.typeParameters;
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

// see CodeCompletions.appendTypeParameters
shared void appendTypeParametersWithArguments(Declaration d, 
    Reference? pr, Unit unit, StringBuilder result, 
    Boolean variances) {


    if (d.parameterized) {
        result.append("<");

        { *d.typeParameters }.fold(true, (isFirst, tp) {
            if (!isFirst) {
                result.append(", ");
            }

            if (exists arg = if (exists pr) then pr.typeArguments[tp] else null) {
                if (is Type pr, variances) {
                    switch (variance = pr.varianceOverrides[tp])
                    case (SiteVariance.\iOUT) {
                        result.append("out ");
                    }
                    case (SiteVariance.\iIN) {
                        result.append("in ");
                    }
                    else if (tp.covariant) {
                        result.append("out ");
                    }
                    else if (tp.contravariant) {
                        result.append("in ");
                    }
                }
                result.append(arg.asString(unit));
            }
            else {
                if (variances) {
                    if (tp.covariant) {
                        result.append("out ");
                    }
                    else if (tp.contravariant) {
                        result.append("in ");
                    }
                }
                result.append(tp.name);
            }

            return false;
        });

        result.append(">");
    }
}

void appendDeclarationHeaderDescription(Declaration d, Reference? pr, Unit unit,
    StringBuilder result)
        => appendDeclarationHeader(d, pr, unit, result, true);

void appendDeclarationHeaderText(Declaration d, Reference? pr, Unit unit,
    StringBuilder result)
        => appendDeclarationHeader(d, pr, unit, result, false);

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
            builder.append(decl.anonymous then "object" else "class");
        }
        case (is Interface) {
            builder.append("interface");
        }
        case (is TypeAlias) {
            builder.append("alias");
        }
        case (is TypedDeclaration) {
            value sequenced 
                    = if (is FunctionOrValue decl)
                    then decl.parameter
                      && decl.initializerParameter.sequenced
                    else false;
            
            Type? tt = if (exists pr) then pr.type else decl.type;
            Type type;
            if (sequenced, exists tt,
                //TODO: nasty workaround because unit can be null
                //      in docs for Open dialogs
                !tt.typeArgumentList.empty) {
                //type = unit.getIteratedType(type);
                type = tt.typeArgumentList[0] else unit.unknownType;
            }
            else {
                type = tt else unit.unknownType;
            }

            String typeName
                    = descriptionOnly
                    then type.asString(unit)
                    else type.asSourceCodeString(unit);
            
            if (decl.dynamicallyTyped) {
                builder.append("dynamic");
            } else if (is Value decl, type.declaration.anonymous, !type.typeConstructor) {
                builder.append("object");
            } else if (is Functional decl) {
                builder.append(decl.declaredVoid then "void" else typeName);
            } else {
                builder.append(typeName);
            }
            
            if (sequenced) {
                builder.append(if (is FunctionOrValue decl,
                    decl.initializerParameter.atLeastOne)
                    then "+" else "*");
            }
        }
        else {
        }
    }
    
    builder.append(" ");
    
    if (exists name = decl.name) {
        builder.append(descriptionOnly then name
            else escaping.escapeName(decl));
    }
}


void appendNamedArgumentHeader(Parameter p, Reference? pr, StringBuilder result,
    Boolean descriptionOnly) {
    
    if (is Functional fp = p.model, fp.declaredVoid) {
        result.append("void").append(" ");
    }
    result.append(descriptionOnly then p.name
        else escaping.escapeName(p.model));
}

void appendImplText(Declaration d, Reference? pr, Boolean isInterface, Unit unit,
    String indent, StringBuilder result, ClassOrInterface? ci) {
    
    if (is Function d) {
        if (exists ci, !ci.anonymous, d.name=="equals") {
            if (exists pl = d.parameterLists[0]) {
                value ps = pl.parameters;
                if (!ps.empty) {
                    appendEqualsImpl(unit, indent, result, ci, ps);
                    return;
                }
            }
        }
        if (!d.formal) {
            result.append(" => super.").append(d.name);
            appendSuperArgsText(d, pr, unit, result, true);
            result.append(";");
        } else {
            if (d.declaredVoid) {
                result.append(" {}");
            } else {
                result.append(" => nothing;");
            }
        }
    } else if (is Value d) {
        if (exists ci, !ci.anonymous, d.name=="hash") {
            appendHashImpl(unit, indent, result, ci);
            return;
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
            value arrow = isVariable(d) then " = " else " => ";
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
            exists name = m.name,
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
        if (!(v.type?.integer else false)) {
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
    
    assert (exists p = ps[0]);
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
    return if (exists name = m.name)
        then m.name=="hash" || m.name=="string"
        else false;
}

void appendMembersToEquals(Unit unit, String indent, StringBuilder result,
    ClassOrInterface ci, Parameter p) {
    
    variable value found = false;
    for (m in ci.members) {
        if (is Value m, 
            exists name = m.name,
            !isObjectField(m) && !isConstructor(m),
            !m.transient,
            intersectionType(unit.nullType, m.type, unit).nothing) {
            if (found) {
                result.append(" && ").append(indent);
            }
            result.append(name)
                  .append("==")
                  .append(p.name)
                  .append(".")
                  .append(name);
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
    
    for (m in ci.members) {
        if (is Value m, 
            exists name = m.name,
            !isObjectField(m) && !isConstructor(m),
            !m.transient,
            intersectionType(unit.nullType, m.type, unit).nothing) {
            result.append("hash = 31*hash + ").append(name);
            if (exists type = m.type) {
                if (! type.integer) {
                    result.append(".hash");
                }
            } else {
                result.append(".hash");
            }
            result.append(";").append(indent);
        }
    }
}

String extraIndent(String indent, Boolean containsNewline) 
        => containsNewline
        then indent + platformServices.document.defaultIndent
        else indent;

shared void appendParametersText(Declaration d, Reference? pr, Unit unit,
    StringBuilder result) {
    appendParameters(d, pr, unit, result, null, false);
}

void appendParameters(Declaration d, Reference? pr,
    Unit unit, StringBuilder result, LocalAnalysisResult? cpc,
    Boolean descriptionOnly) {
    if (is Functional d,
        exists plists = d.parameterLists) {
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

shared void appendParameter(StringBuilder result, Reference? pr, Parameter p,
    Unit unit, Boolean descriptionOnly) {
    
    if (!exists mod = p.model) {
        result.append(p.name);
    } else {
        value ppr = pr?.getTypedParameter(p);
        appendDeclarationHeader(p.model, ppr, unit, result, descriptionOnly);
        appendParameters(p.model, ppr, unit, result, null, descriptionOnly);
    }
}


// see CodeCompletions.appendParametersDescription
void appendParametersDescription(Declaration d,
    Reference? pr, Unit unit, StringBuilder result, Boolean descriptionOnly,
    LocalAnalysisResult? cmp)
        => appendParameters(d, pr, d.unit, result, cmp, descriptionOnly);
