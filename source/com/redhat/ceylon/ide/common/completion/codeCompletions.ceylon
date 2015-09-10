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
    ...
}
import java.util {
    List,
    Collections
}
// see CodeCompletions.getDocDescriptionFor
shared String getDocDescriptionFor<Document,IdeArtifact>(Declaration decl, Reference? pr, Unit unit,
    LocalAnalysisResult<Document,IdeArtifact> cmp) {
    StringBuilder result = StringBuilder();
    
    appendDeclarationHeader(decl, pr, unit, result, true);
    appendTypeParameters(decl, pr, unit, result, true);
    appendParametersDescription(decl, pr, unit, result, true, cmp);
    
    return result.string;
}

shared String getTextFor(Declaration dec, Unit unit) {
    value result = StringBuilder();
    result.append(escaping.escapeName(dec, unit));
    appendTypeParameters2(dec, result);
    return result.string;
}

shared String getInlineFunctionTextFor(Parameter p, Reference? pr, Unit unit, String indent) {
    value result = StringBuilder();
    appendNamedArgumentHeader(p, pr, result, false);
    appendTypeParameters2(p.model, result);
    appendParametersText(p.model, pr, unit, result);
    if (p.declaredVoid) {
        result.append(" {}");
    } else {
        result.append(" => nothing;");
    }
    return result.string;
}

void appendNamedArgumentHeader(Parameter p, Reference? pr, StringBuilder result, Boolean descriptionOnly) {
    if (is Functional fp = p.model) {
        result.append(if (fp.declaredVoid) then "void" else "function");
    } else {
        result.append("value");
    }
    result.append(" ").append(if (descriptionOnly) then p.name else escaping.escapeName(p.model));
}

shared void appendParametersText(Declaration d, Reference? pr, Unit unit, StringBuilder result) {
    appendParameters(d, pr, unit, result, null, false);
}

// see CodeCompletions.appendDeclarationHeader
void appendDeclarationHeader(Declaration decl, Reference? pr, Unit unit, StringBuilder builder, Boolean descriptionOnly) {
    if (is TypeAlias decl, decl.anonymous) {
        return;
    }
    
    if (ModelUtil.isConstructor(decl)) {
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
            value sequenced = if (is FunctionOrValue fov = decl, decl.parameter, fov.initializerParameter.sequenced)
            then true else false;
            
            variable Type? type = if (exists pr) then pr.type else decl.type;
            
            if (sequenced, exists t = type) {
                if (!t.typeArgumentList.empty) {
                    type = t.typeArgumentList.get(0);
                }
            }
            
            if (!exists t = type) {
                type = UnknownType(unit).type;
            }
            
            assert (exists t = type);
            
            String typeName = if (descriptionOnly) then t.asString(unit) else t.asSourceCodeString(unit);
            
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
                builder.append(if (is FunctionOrValue decl, decl.initializerParameter.atLeastOne) then "+" else "*");
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

void appendTypeParameters2(Declaration d, StringBuilder result, Boolean variances = false) {
    if (is Generic d) {
        value types = (d).typeParameters;
        if (!types.empty) {
            result.append("<");
            for (tp in CeylonIterable(types)) {
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
shared void appendTypeParameters(Declaration d, Reference? pr, Unit unit, StringBuilder result, Boolean variances) {
    if (is Generic d) {
        value types = d.typeParameters;
        
        if (!types.empty) {
            result.append("&lt;");
            
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
                            SiteVariance? variance = pr.varianceOverrides.get(tp);
                            
                            if (!exists variance) {
                                if (tp.covariant) {
                                    result.append("out ");
                                } else if (tp.contravariant) {
                                    result.append("in ");
                                }
                            } else if (variance == SiteVariance.\iOUT) {
                                result.append("out ");
                            } else if (variance == SiteVariance.\iIN) {
                                result.append("in ");
                            }
                        }
                        result.append(tp.name);
                    }
                    
                    return false;
                });
            
            result.append("&gt;");
        }
    }
}

// see CodeCompletions.appendParametersDescription
void appendParametersDescription<Document,IdeArtifact>(Declaration decl, Reference? pr, Unit unit, StringBuilder result, Boolean descriptionOnly,
    LocalAnalysisResult<Document,IdeArtifact> cmp) {
    if (is Functional decl, exists plists = decl.parameterLists) {
        CeylonIterable(plists).each(void(params) {
                if (params.parameters.empty) {
                    result.append("()");
                } else {
                    result.append("(");
                    
                    CeylonIterable(params.parameters).fold(true)((isFirst, param) {
                            if (!isFirst) { result.append(", "); }
                            
                            appendParameterDescription(param, pr, unit, result, descriptionOnly, cmp);
                            result.append(getDefaultValueDescription(param, cmp));
                            
                            return false;
                        });
                    
                    result.append(")");
                }
            });
    }
}

void appendParameterDescription<Document,IdeArtifact>(Parameter param, Reference? pr, Unit unit, StringBuilder result,
    Boolean descriptionOnly, LocalAnalysisResult<Document,IdeArtifact> cmp) {
    if (exists model = param.model) {
        TypedReference? ppr = pr?.getTypedParameter(param) else null;
        appendDeclarationHeader(model, ppr, unit, result, descriptionOnly);
        appendParametersDescription(model, ppr, unit, result, descriptionOnly, cmp);
    } else {
        result.append(param.name);
    }
}

shared String getRefinementTextFor(Declaration d, Reference pr, Unit unit, Boolean isInterface, ClassOrInterface ci,
    String indent, Boolean containsNewline, Boolean preamble) {
    value result = StringBuilder();
    if (preamble) {
        result.append("shared actual ");
        if (isVariable(d), !isInterface) {
            result.append("variable ");
        }
    }
    appendDeclarationHeaderText(d, pr, unit, result);
    appendTypeParameters2(d, result);
    appendParameters(d, pr, unit, result, null, true);
    if (is Class d) {
        result.append(extraIndent(extraIndent(indent, containsNewline), containsNewline)).append(" extends super.").append(escaping.escapeName(d));
        appendPositionalArgs(d, pr, unit, result, true, false);
    }
    appendConstraints(d, pr, unit, indent, containsNewline, result);
    appendImplText(d, pr, isInterface, unit, indent, result, ci);
    return result.string;
}

void appendConstraints(Declaration d, Reference pr, Unit unit, String indent, Boolean containsNewline, StringBuilder result) {
    if (is Generic d) {
        value generic = d;
        for (tp in CeylonIterable(generic.typeParameters)) {
            value sts = tp.satisfiedTypes;
            if (!sts.empty) {
                result.append(extraIndent(extraIndent(indent, containsNewline), containsNewline)).append("given ").append(tp.name).append(" satisfies ");
                variable Boolean first = true;
                for (st in CeylonIterable(sts)) {
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

void appendImplText(Declaration d, Reference pr, Boolean isInterface, Unit unit, String indent, StringBuilder result, ClassOrInterface? ci) {
    if (is Function d) {
        if (exists ci, !ci.anonymous) {
            if (d.name.equals("equals")) {
                value pl = (d).parameterLists;
                if (!pl.empty) {
                    value ps = pl.get(0).parameters;
                    if (!ps.empty) {
                        // TODO appendEqualsImpl(unit, indent, result, ci, ps);
                        return;
                    }
                }
            }
        }
        if (!d.formal) {
            result.append(" => super.").append(d.name);
            // TODO appendSuperArgsText(d, pr, unit, result, true);
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
                // TODO appendHashImpl(unit, indent, result, ci);
                return;
            }
        }
        if (isInterface) {
            if (d.formal) {
                result.append(" => nothing;");
            } else {
                result.append(" => super.").append(d.name).append(";");
            }
            if (isVariable(d)) {
                result.append(indent).append("assign ").append(d.name).append(" {}");
            }
        } else {
            value arrow = if (isVariable(d)) then " = " else " => ";
            if (d.formal) {
                result.append(arrow).append("nothing;");
            } else {
                result.append(arrow).append("super.").append(d.name).append(";");
            }
        }
    } else {
        result.append(" {}");
    }
}

List<Parameter> getParametersFunctional(Functional fd, Boolean includeDefaults, Boolean namedInvocation) {
    List<ParameterList>? plists = fd.parameterLists;
    if (plists?.empty else true) {
        return Collections.emptyList<Parameter>();
    } else {
        assert (exists plists);
        return getParameters(plists.get(0), includeDefaults, namedInvocation);
    }
}

void appendPositionalArgs(Declaration d, Reference pr, Unit unit, StringBuilder result, Boolean includeDefaulted, Boolean descriptionOnly) {
    if (is Functional d) {
        value params = getParametersFunctional(d, includeDefaulted, false);
        if (params.empty) {
            result.append("()");
        } else {
            value paramTypes = descriptionOnly /* TODO && preferences.getBoolean(\iPARAMETER_TYPES_IN_COMPLETIONS)*/;
            result.append("(");
            for (p in CeylonIterable(params)) {
                value typedParameter = pr.getTypedParameter(p);
                if (is Functional mod = p.model) {
                    if (p.declaredVoid) {
                        result.append("void ");
                    }
                    appendParameters(mod, typedParameter, unit, result, null, descriptionOnly);
                    if (p.declaredVoid) {
                        result.append(" {}");
                    } else {
                        result.append(" => ").append("nothing");
                    }
                } else {
                    variable Type pt = typedParameter.type;
                    if (paramTypes, !ModelUtil.isTypeUnknown(pt)) {
                        if (p.sequenced) {
                            pt = unit.getSequentialElementType(pt);
                        }
                        result.append(pt.asString(unit));
                        if (p.sequenced) {
                            result.append(if (p.atLeastOne) then "+" else "*");
                        }
                        result.append(" ");
                    } else if (p.sequenced) {
                        result.append("*");
                    }
                    FunctionOrValue? mod = p.model;
                    result.append(if (descriptionOnly || mod is Null) then p.name else escaping.escapeName(p.model));
                }
                result.append(", ");
            }
            result.deleteTerminal(2);
            result.append(")");
        }
    }
}

shared Boolean isVariable(Declaration d) {
    return if (is TypedDeclaration d, d.variable) then true else false;
}

String extraIndent(String indent, Boolean containsNewline) {
    return if (containsNewline) then indent /* TODO + indents.defaultIndent*/ else indent;
}

void appendDeclarationHeaderDescription(Declaration d, Reference pr, Unit unit, StringBuilder result) {
    appendDeclarationHeader(d, pr, unit, result, true);
}

void appendDeclarationHeaderText(Declaration d, Reference pr, Unit unit, StringBuilder result) {
    appendDeclarationHeader(d, pr, unit, result, false);
}

void appendParameters<Document,IdeArtifact>(Declaration d, Reference? pr, Unit unit, StringBuilder result, LocalAnalysisResult<Document,IdeArtifact>? cpc, Boolean descriptionOnly) {
    if (is Functional d) {
        if (exists plists = d.parameterLists) {
            for (params in CeylonIterable(plists)) {
                if (params.parameters.empty) {
                    result.append("()");
                } else {
                    result.append("(");
                    for (p in CeylonIterable(params.parameters)) {
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

void appendParameter(StringBuilder result, Reference? pr, Parameter p, Unit unit, Boolean descriptionOnly) {
    if (!exists mod = p.model) {
        result.append(p.name);
    } else {
        value ppr = if (!exists pr) then null else pr.getTypedParameter(p);
        appendDeclarationHeader(p.model, ppr, unit, result, descriptionOnly);
        appendParameters(p.model, ppr, unit, result, null, descriptionOnly);
    }
}

shared String getNamedInvocationTextFor(Declaration dec, Reference pr, Unit unit, Boolean includeDefaulted, String? typeArgs) {
    value result = StringBuilder();
    result.append(escaping.escapeName(dec, unit));
    if (exists typeArgs) {
        result.append(typeArgs);
    } else if (forceExplicitTypeArgs(dec, null)) {
        appendTypeParameters2(dec, result);
    }
    appendNamedArgs(dec, pr, unit, result, includeDefaulted, false);
    appendSemiToVoidInvocation(result, dec);
    return result.string;
}

Boolean forceExplicitTypeArgs(Declaration d, OccurrenceLocation? ol) {
    if (isLocation(ol, OccurrenceLocation.\iEXTENDS)) {
        return true;
    } else {
        if (is Functional d) {
            value pls = (d).parameterLists;
            return pls.empty || pls.get(0).parameters.empty;
        } else {
            return false;
        }
    }
}

void appendNamedArgs(Declaration d, Reference pr, Unit unit, StringBuilder result, Boolean includeDefaulted, Boolean descriptionOnly) {
    if (is Functional d) {
        value params = getParametersFunctional(d, includeDefaulted, true);
        if (params.empty) {
            result.append(" {}");
        } else {
            value paramTypes = descriptionOnly; // TODO && preferences.getBoolean(\iPARAMETER_TYPES_IN_COMPLETIONS);
            result.append(" { ");
            for (p in CeylonIterable(params)) {
                value name = if (descriptionOnly) then p.name else escaping.escapeName(p.model);
                if (is Functional mod = p.model) {
                    if (p.declaredVoid) {
                        result.append("void ");
                    } else {
                        if (paramTypes, !ModelUtil.isTypeUnknown(p.type)) {
                            value ptn = p.type.asString(unit);
                            result.append(ptn).append(" ");
                        } else {
                            result.append("function ");
                        }
                    }
                    result.append(name);
                    appendParameters(p.model, pr.getTypedParameter(p), unit, result, null, descriptionOnly);
                    if (descriptionOnly) {
                        result.append("; ");
                    } else if (p.declaredVoid) {
                        result.append(" {} ");
                    } else {
                        result.append(" => ").append("nothing; ");
                    }
                } else {
                    if (p == params.get(params.size() - 1), !ModelUtil.isTypeUnknown(p.type), unit.isIterableParameterType(p.type)) {
                    } else {
                        if (paramTypes, !ModelUtil.isTypeUnknown(p.type)) {
                            value ptn = p.type.asString(unit);
                            result.append(ptn).append(" ");
                        }
                        result.append(name).append(" = ").append("nothing").append("; ");
                    }
                }
            }
            result.append("}");
        }
    }
}

void appendSemiToVoidInvocation(StringBuilder result, Declaration dd) {
    if (is Function dd, dd.declaredVoid, dd.parameterLists.size() == 1) {
        result.append(";");
    }
}

