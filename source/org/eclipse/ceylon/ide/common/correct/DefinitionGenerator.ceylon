/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.util {
    escaping
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Type,
    TypeDeclaration,
    TypeParameter
}

import java.util {
    Collection,
    LinkedHashMap,
    List,
    Map
}

shared abstract class DefinitionGenerator() {
    
    shared String generateShared(String indent, String delim) 
            => "shared " + generateInternal(indent, delim, false);
    
    shared String generate(String indent, String delim) 
            => generateInternal(indent, delim, false);
    
    shared String generateSharedFormal(String indent, String delim) 
            => "shared formal " + generateInternal(indent, delim, true);
    
    shared formal String generateInternal(String indent, String delim, Boolean isFormal);
        
    shared formal Boolean isFormalSupported;
    
    shared formal void generateImports(CommonImportProposals importProposals);
    
    shared formal String brokenName;
    
    shared formal String description;
    
    shared formal Type? returnType;
    
    shared formal Map<String,Type>? parameters;
    
    shared formal Icons image;
    
    shared formal Tree.CompilationUnit rootNode;
    
    shared formal Node node;
    
    shared void appendParameters(Map<String,Type> parameters, 
        StringBuilder buffer, 
        TypeDeclaration supertype = node.unit.anythingDeclaration) {
        if (parameters.empty) {
            buffer.append("()");
        } else {
            buffer.append("(");
            for (e in parameters.entrySet()) {
                Declaration? member 
                        = supertype.getMember(e.key, null, false);
                if (!(member?.formal else false)) {
                    buffer.append(e.\ivalue.asSourceCodeString(node.unit)).append(" ");
                }
                buffer.append(e.key).append(", ");
            }
            buffer.deleteTerminal(2);
            buffer.append(")");
        }
    }
    
    shared void appendTypeParams(List<TypeParameter> typeParams, 
        StringBuilder typeParamDef, StringBuilder typeParamConstDef, 
        TypeParameter typeParam) {
        if (typeParams.contains(typeParam)) {
            return;
        } else {
            typeParams.add(typeParam);
        }
        if (typeParam.contravariant) {
            typeParamDef.append("in ");
        }
        if (typeParam.covariant) {
            typeParamDef.append("out ");
        }
        typeParamDef.append(typeParam.name);
        if (typeParam.defaulted, 
            exists dta = typeParam.defaultTypeArgument) {
            typeParamDef.append("=");
            typeParamDef.append(dta.asString());
        }
        typeParamDef.append(",");
        if (typeParam.constrained) {
            typeParamConstDef.append(" given ");
            typeParamConstDef.append(typeParam.name);
            if (exists satisfiedTypes = typeParam.satisfiedTypes, 
                !satisfiedTypes.empty) {
                typeParamConstDef.append(" satisfies ");
                variable value firstSatisfiedType = true;
                for (satisfiedType in satisfiedTypes) {
                    if (firstSatisfiedType) {
                        firstSatisfiedType = false;
                    } else {
                        typeParamConstDef.append("&");
                    }
                    typeParamConstDef.append(satisfiedType.asString());
                }
            }
            if (exists caseTypes = typeParam.caseTypes, 
                !caseTypes.empty) {
                typeParamConstDef.append(" of ");
                variable value firstCaseType = true;
                for (caseType in caseTypes) {
                    if (firstCaseType) {
                        firstCaseType = false;
                    } else {
                        typeParamConstDef.append("|");
                    }
                    typeParamConstDef.append(caseType.asString());
                }
            }
        }
    }
    
    shared void appendTypeParams2(List<TypeParameter> typeParams, 
        StringBuilder typeParamDef, StringBuilder typeParamConstDef, 
        Type? pt) {
        if (exists pt) {
            if (pt.union) {
                appendTypeParams3(typeParams, 
                    typeParamDef, typeParamConstDef, 
                    pt.caseTypes);
            } else if (pt.intersection) {
                appendTypeParams3(typeParams, 
                    typeParamDef, typeParamConstDef, 
                    pt.satisfiedTypes);
            } else if (pt.typeParameter) {
                assert(is TypeParameter decl = pt.declaration);
                appendTypeParams(typeParams, 
                    typeParamDef, typeParamConstDef, decl);
            }
        }
    }
    
    shared void appendTypeParams3(List<TypeParameter> typeParams, 
        StringBuilder typeParamDef, StringBuilder typeParamConstDef, 
        Collection<Type>? parameterTypes) {
        
        if (exists parameterTypes) {
            for (pt in parameterTypes) {
                appendTypeParams2(typeParams, 
                    typeParamDef, typeParamConstDef, pt);
            }
        }
    }
}

LinkedHashMap<String,Type> getParametersFromPositionalArgs(
    Tree.PositionalArgumentList pal) {
    value types = LinkedHashMap<String,Type>();
    variable value i = 0;
    for (pa in pal.positionalArguments) {
        if (is Tree.ListedArgument pa) {
            value la = pa;
            value e = la.expression;
            Type? et = e.typeModel;
            variable String name;
            Type t;
            value unit = pa.unit;
            if (!exists et) {
                t = unit.anythingType;
                name = "arg";
            } else {
                t = unit.denotableType(et);
                value term = e.term;
                if (is Tree.StaticMemberOrTypeExpression term) {
                    value smte = term;
                    value id = smte.identifier.text;
                    name = escaping.toInitialLowercase(id);
                } else {
                    if (et.classOrInterface || et.typeParameter) {
                        value tn = et.declaration.name;
                        name = escaping.toInitialLowercase(tn);
                    } else {
                        name = "arg";
                    }
                }
            }
            if (types.containsKey(name)) {
                i++;
                name = name + i.string;
            }
            types[name] = t;
        }
    }
    return types;
}

LinkedHashMap<String,Type> getParametersFromNamedArgs(
    Tree.NamedArgumentList nal) {
    value types = LinkedHashMap<String,Type>();
    variable value i = 0;
    for (a in nal.namedArguments) {
        if (is Tree.SpecifiedArgument a) {
            Tree.Expression? e = a.specifierExpression.expression;
            variable value name = a.identifier?.text else "";
            value unit = a.unit;
            value type = 
                    if (!exists e) 
                    then unit.anythingType 
                    else unit.denotableType(e.typeModel);
            if (types.containsKey(name)) {
                i++;
                name = name + i.string;
            }
            types[name] = type;
        }
    }
    return types;
}

LinkedHashMap<String,Type>? getParameters(FindArgumentsVisitor fav) {
    if (exists f = fav.positionalArgs) {
        return getParametersFromPositionalArgs(f);
    } else if (exists f = fav.namedArgs) {
        return getParametersFromNamedArgs(f);
    } else {
        return null;
    }
}
