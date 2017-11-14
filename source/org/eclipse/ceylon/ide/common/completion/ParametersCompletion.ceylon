/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.interop.java {
	CeylonList
}

import org.eclipse.ceylon.compiler.typechecker.analyzer {
	Warning
}
import org.eclipse.ceylon.compiler.typechecker.tree {
	Tree
}
import org.eclipse.ceylon.ide.common.doc {
	Icons
}
import org.eclipse.ceylon.ide.common.platform {
	platformServices
}
import org.eclipse.ceylon.ide.common.util {
	escaping
}
import org.eclipse.ceylon.model.typechecker.model {
	Type,
	Functional
}

shared interface ParametersCompletion {
    
    // see ParametersCompletionProposal.addParametersProposal(final int offset, Node node, final List<ICompletionProposal> result, CeylonParseController cpc)
    shared void addParametersProposal(Integer offset, String prefix, 
        Tree.Term node, CompletionContext ctx) {
        
        value condition
                = if (is Tree.StaticMemberOrTypeExpression node)
                then !node.declaration is Functional
                else true;
        
        if (condition, 
            exists unit = node.unit, 
            exists type = node.typeModel) {
            value cd = unit.callableDeclaration;
            value td = type.declaration;
            
            if (td.qualifiedNameString == "ceylon.language::SuppressWarningsAnnotation") {
                value warnings = { for (w in Warning.values()) w.name() };
                
                for (val in sort(warnings)) {
                    platformServices.completion.addProposal {
                    	ctx = ctx;
                    	offset = offset;
                    	prefix = prefix;
                    	icon = Icons.ceylonLiteral;
                    	description = "\"``val``\"";
                    };
                }
            }
            if (type.classOrInterface, td==cd) {
                value argTypes = unit.getCallableArgumentTypes(type);
                value paramTypes = ctx.options.parameterTypesInCompletion;
                value desc = StringBuilder().append("(");
                value text = StringBuilder().append("(");
                
                for (i in 0:argTypes.size()) {
                    if (desc.size > 1) {
                        desc.append(", ");
                    }
                    if (text.size > 1) {
                        text.append(", ");
                    }
                    Type returnType;
                    if (exists argType = argTypes[i]) {
                        if (argType.classOrInterface,
                            argType.declaration == cd) {
                            String anon = 
                                    anonFunctionHeader(argType, unit);
                            text.append(anon).append(" => ");
                            desc.append(anon).append(" => ");
                            returnType = unit.getCallableReturnType(argType);
                            argTypes[i] = returnType;
                        }
                        else if (paramTypes) {
                            returnType = argType;
                            desc.append(argType.asString(unit))
                                .append(" ");
                        }
                        else {
                            returnType = argType;
                        }
                    }
                    else {
                        returnType = unit.unknownType;
                    }
                    
                    String name;
                    if (returnType.classOrInterface
                        || returnType.typeParameter) {
                        String n = returnType.declaration.getName(unit);
                        name = escaping.toInitialLowercase(n);
                    }
                    else {
                        name = "it";
                    }
                    text.append(name);
                    desc.append(name);

                }
                text.append(")");
                desc.append(")");

                platformServices.completion.newParametersCompletionProposal {
                    ctx = ctx;
                    offset = offset;
                    prefix = prefix;
                    desc = desc.string;
                    text = text.string;
                    argTypes = CeylonList(argTypes);
                    node = node;
                    unit = unit;
                };
            }
        }
    }
}