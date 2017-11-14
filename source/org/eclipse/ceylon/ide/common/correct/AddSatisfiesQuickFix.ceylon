/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    ArrayList
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Node,
    Tree {
        TypeConstraintList
    },
    Visitor
}
import org.eclipse.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.search {
    FindContainerVisitor
}
import org.eclipse.ceylon.ide.common.util {
    FindDeclarationNodeVisitor
}
import org.eclipse.ceylon.model.typechecker.model {
    ClassOrInterface,
    Declaration,
    Type,
    TypeDeclaration,
    TypeParameter
}

import java.util {
    HashMap
}
import java.lang {
    overloaded
}

"Add generic type constraints proposal for following code:
 
     interface Foo<T> given T satisfies Comparable<T> {}
     class Bar<T>() satisfies Foo<T> {}
     ------
     void foo<T>(T t) {
        Bar b = t;
     }
     ------
     void foo<T>(T t) {
        Entry<Integer, T> e;
     }

 "
// TODO automatically import satisfied type if needed
shared object addSatisfiesQuickFix {
    
    shared void addSatisfiesProposals(QuickFixData data) {
        value node = determineNode(data.node);
        if (exists typeDec = determineTypeDeclaration(node)) {

            value isTypeParam = typeDec is TypeParameter;
            value missingSatisfiedTypes
                    = let (types = determineMissingSatisfiedTypes(data.rootNode, node, typeDec))
                    if (isTypeParam) then types else types.filter(Type.\iinterface);

            //TODO: add extends clause if the type is a class
            //      which extends Basic

            if (missingSatisfiedTypes.empty) {
                return;
            }

            value changeText = correctionUtil.asIntersectionTypeString(missingSatisfiedTypes);
            if (is AnyModifiableSourceFile unit = typeDec.unit,
                exists phasedUnit = unit.phasedUnit,
                exists declaration
                        = determineContainer(phasedUnit.compilationUnit, typeDec)) {

                createProposals {
                    data = data;
                    typeDec = typeDec;
                    isTypeParam = isTypeParam;
                    changeText = changeText;
                    declaration = declaration;
                    sameFile = node.unit==unit;
                };
            }
        }
    }
    
    void createProposals(QuickFixData data, TypeDeclaration typeDec, Boolean isTypeParam,
        String changeText, Node declaration, Boolean sameFile) {
        
        if (isTypeParam) {
            switch (declaration)
            case (is Tree.ClassDefinition) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.classBody, sameFile);
            } case (is Tree.InterfaceDefinition) {
                addConstraintSatisfiesProposals(typeDec, changeText, data, 
                    declaration.typeConstraintList,
                    declaration.interfaceBody, sameFile);
            } case (is Tree.MethodDefinition) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.block, sameFile);
            } case (is Tree.ClassDeclaration) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.classSpecifier, sameFile);
            } case (is Tree.InterfaceDeclaration) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.typeSpecifier, sameFile);
            } case (is Tree.MethodDeclaration) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.specifierExpression, sameFile);
            }
            else {}
        } else {
            switch (declaration)
            case (is Tree.ClassDefinition) {
                addSatisfiesProposals2(typeDec, changeText, data, 
                    declaration.satisfiedTypes,
                    declaration.typeConstraintList else declaration.classBody,
                    sameFile);
            } case (is Tree.ObjectDefinition) {
                addSatisfiesProposals2(typeDec, changeText, data, 
                    declaration.satisfiedTypes,
                    declaration.classBody, sameFile);
            } case (is Tree.InterfaceDefinition) {
                addSatisfiesProposals2(typeDec, changeText, data, 
                    declaration.satisfiedTypes,
                    declaration.typeConstraintList else declaration.interfaceBody,
                    sameFile);
            }
            else {}
        }
    }
    
    void addConstraintSatisfiesProposals(TypeDeclaration typeParam, 
        String missingSatisfiedType, QuickFixData data, 
        TypeConstraintList? typeConstraints, Node? typeContainerBody,
        Boolean sameFile) {

        value typeContainerBodyStartIndex =
                typeContainerBody?.startIndex?.intValue();
        if (!exists typeContainerBodyStartIndex) {
            return;
        }

        variable String? changeText = null;
        variable Integer? changeIndex = null;
        if (exists typeConstraints) {
            for (typeConstraint in typeConstraints.typeConstraints) {
                if (typeConstraint.declarationModel==typeParam) {
                    changeText = " & " + missingSatisfiedType;
                    changeIndex = typeConstraint.endIndex.intValue();
                    break;
                }
            }
        }
        
        if (!exists ct = changeText) {
            changeText = "given ``typeParam.name`` satisfies ``missingSatisfiedType`` ";
            changeIndex = typeContainerBodyStartIndex;
        }
        
        if (exists ct = changeText) {
            value tfc = platformServices.document.createTextChange("Add Type Constraint", data.phasedUnit);
            assert(exists ci = changeIndex);
            tfc.addEdit(InsertEdit(ci, ct));

            data.addQuickFix {
                description
                        = "Add generic type constraint '``typeParam.name`` satisfies ``missingSatisfiedType``'";
                change = tfc;
                selection = sameFile then DefaultRegion(ci, ct.size);
                affectsOtherUnits = true;
            };
        }
    }
    
    void addSatisfiesProposals2(TypeDeclaration typeParam, String missingSatisfiedType,
        QuickFixData data, Tree.SatisfiedTypes? typeConstraints, 
        Node? typeContainerBody, Boolean sameFile) {

        value typeContainerBodyStartIndex =
                typeContainerBody?.startIndex?.intValue();
        if (!exists typeContainerBodyStartIndex) {
            return;
        }

        String changeText;
        Integer changeIndex;
        if (exists typeConstraints) {
            changeText = " & " + missingSatisfiedType;
            changeIndex = typeConstraints.endIndex.intValue();
        } else {
            changeText = "satisfies " + missingSatisfiedType + " ";
            changeIndex = typeContainerBodyStartIndex;
        }
        
        value tfc = platformServices.document.createTextChange("Add Inherited Interface", data.phasedUnit);
        tfc.addEdit(InsertEdit(changeIndex, changeText));

        data.addQuickFix {
            description
                    = "Add inherited interface '``typeParam.name`` satisfies ``missingSatisfiedType``'";
            change = tfc;
            selection = sameFile then DefaultRegion(changeIndex, changeText.size);
            affectsOtherUnits = true;
        };
    }
    
    Node determineNode(Node node)
            => switch (node)
            case (is Tree.SpecifierExpression) node.expression
            case (is Tree.Expression) node.term
            else node;
    
    TypeDeclaration? determineTypeDeclaration(Node node) {

        switch (node)
        case (is Tree.ClassOrInterface
               | Tree.TypeParameterDeclaration) {
            if (is ClassOrInterface declaration //TODO: huh? this looks wrong!!
                    = node.declarationModel) {
                return declaration;
            }
            else {
                return null;
            }
        } case (is Tree.ObjectDefinition) {
            return node.declarationModel.type.declaration;
        } case (is Tree.BaseType) {
            return node.declarationModel;
        } case (is Tree.Term) {
            return node.typeModel?.declaration;
        }
        else {
            return null;
        }
    }
    
    Node? determineContainer(Tree.CompilationUnit rootNode, TypeDeclaration typeDec) {
        value fdv = object extends FindDeclarationNodeVisitor(typeDec) {
            shared actual void visit(Tree.ObjectDefinition that) {
                if (that.declarationModel.type.declaration==typeDec) {
                    declarationNode = that;
                }
                
                super.visit(that);
            }
        };
        fdv.visit(rootNode);
        if (is Tree.Declaration dec = fdv.declarationNode) {
            value fcv = FindContainerVisitor(dec);
            fcv.visit(rootNode);
            return fcv.statementOrArgument;
        }
        
        return null;
    }
    
    List<Type> determineMissingSatisfiedTypes(Tree.CompilationUnit rootNode, 
        Node node, TypeDeclaration typeDec) {
        
        value missingSatisfiedTypes = ArrayList<Type>();
        if (is Tree.Term node) {
            value fav = FindInvocationVisitor(node);
            fav.visit(rootNode);
            if (exists param = fav.parameter) {
                if (exists type = param.type,
                    type.declaration exists) {
                    if (type.classOrInterface) {
                        missingSatisfiedTypes.add(type);
                    } else if (type.intersection) {
                        for (it in type.satisfiedTypes) {
                            if (!typeDec.inherits(it.declaration)) {
                                missingSatisfiedTypes.add(it);
                            }
                        }
                    }
                }
            }
        } else {
            value stTypeParams = determineSatisfiedTypesTypeParams(rootNode, node, typeDec);
            if (!stTypeParams.empty) {
                value typeParamType = typeDec.type;
                value substitutions = HashMap<TypeParameter,Type>();
                for (stTypeParam in stTypeParams) {
                    substitutions[stTypeParam] = typeParamType;
                }
                
                for (stTypeParam in stTypeParams) {
                    for (stTypeParamSatisfiedType in stTypeParam.satisfiedTypes) {
                        value subst = stTypeParamSatisfiedType.substitute(substitutions, null);
                        variable value isMissing = true;
                        for (typeParamSatisfiedType in typeDec.satisfiedTypes) {
                            if (subst.isSupertypeOf(typeParamSatisfiedType)) {
                                isMissing = false;
                                break;
                            }
                        }
                        
                        if (isMissing) {
                            for (missingSatisfiedType in missingSatisfiedTypes) {
                                if (missingSatisfiedType.isExactly(subst)) {
                                    isMissing = false;
                                    break;
                                }
                            }
                        }
                        
                        if (isMissing) {
                            missingSatisfiedTypes.add(subst);
                        }
                    }
                }
            }
        }
        
        return missingSatisfiedTypes;
    }
    
    List<TypeParameter> determineSatisfiedTypesTypeParams(Tree.CompilationUnit rootNode,
            Node typeParamNode, TypeDeclaration typeDec) {
        value stTypeParams = ArrayList<TypeParameter>();
        object extends Visitor() {
            void determineSatisfiedTypesTypeParams(TypeDeclaration typeParam,
                    Declaration? stDecl, Tree.TypeArguments? args, Node typeParamNode) {
                if (is Tree.TypeArgumentList args) {
                    value stTypeArguments = args.types;
                    if (stTypeArguments.contains(typeParamNode),
                        exists stDecl) {
                        for (i in 0:stTypeArguments.size()) {
                            if (is Tree.SimpleType type = stTypeArguments[i],
                                exists td = type.declarationModel,
                                typeParam == td) {

                                value typeParameters = stDecl.typeParameters;
                                if (typeParameters.size() > i) {
                                    stTypeParams.add(typeParameters.get(i));
                                }
                            }
                        }
                    }
                }
            }

            overloaded
            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                determineSatisfiedTypesTypeParams {
                    typeParam = typeDec;
                    stDecl = that.declarationModel;
                    args = that.typeArgumentList;
                    typeParamNode = typeParamNode;
                };
            }

            overloaded
            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                super.visit(that);
                determineSatisfiedTypesTypeParams {
                    typeParam = typeDec;
                    stDecl = that.declaration;
                    args = that.typeArguments;
                    typeParamNode = typeParamNode;
                };
            }
            
        }.visit(rootNode);
        return stTypeParams;
    }

}
