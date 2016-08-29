
import ceylon.collection {
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree {
        TypeConstraintList
    },
    Visitor
}
import com.redhat.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.search {
    FindContainerVisitor
}
import com.redhat.ceylon.ide.common.util {
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    ClassOrInterface,
    Declaration,
    Generic,
    Type,
    TypeDeclaration,
    TypeParameter
}

import java.util {
    HashMap
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
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
        Node? node = determineNode(data.node);
        if (!exists node) {
            return;
        }
        
        TypeDeclaration? typeDec = determineTypeDeclaration(node);
        if (!exists typeDec) {
            return;
        }
        
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
            
            createProposals(data, typeDec, isTypeParam, changeText, 
                declaration, node.unit.equals(unit));
        }
    }
    
    void createProposals(QuickFixData data, TypeDeclaration typeDec, Boolean isTypeParam,
        String changeText, Node declaration, Boolean sameFile) {
        
        if (isTypeParam) {
            if (is Tree.ClassDefinition declaration) {
                value classDefinition = declaration;
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    classDefinition.typeConstraintList, 
                    classDefinition.classBody.startIndex.intValue(), sameFile);
            } else if (is Tree.InterfaceDefinition declaration) {
                value interfaceDefinition = declaration;
                addConstraintSatisfiesProposals(typeDec, changeText, data, 
                    interfaceDefinition.typeConstraintList, 
                    interfaceDefinition.interfaceBody.startIndex.intValue(), sameFile);
            } else if (is Tree.MethodDefinition declaration) {
                value methodDefinition = declaration;
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    methodDefinition.typeConstraintList, 
                    methodDefinition.block.startIndex.intValue(), sameFile);
            } else if (is Tree.ClassDeclaration declaration) {
                value classDefinition = declaration;
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    classDefinition.typeConstraintList, 
                    classDefinition.classSpecifier.startIndex.intValue(), sameFile);
            } else if (is Tree.InterfaceDeclaration declaration) {
                value interfaceDefinition = declaration;
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    interfaceDefinition.typeConstraintList, 
                    interfaceDefinition.typeSpecifier.startIndex.intValue(), sameFile);
            } else if (is Tree.MethodDeclaration declaration) {
                value methodDefinition = declaration;
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    methodDefinition.typeConstraintList, 
                    methodDefinition.specifierExpression.startIndex.intValue(), sameFile);
            }
        } else {
            if (is Tree.ClassDefinition declaration) {
                value classDefinition = declaration;
                addSatisfiesProposals2(typeDec, changeText, data, 
                    classDefinition.satisfiedTypes, 
                    if (!classDefinition.typeConstraintList exists) 
                    then classDefinition.classBody.startIndex.intValue()
                    else classDefinition.typeConstraintList.startIndex.intValue(), sameFile);
            } else if (is Tree.ObjectDefinition declaration) {
                value objectDefinition = declaration;
                addSatisfiesProposals2(typeDec, changeText, data, 
                    objectDefinition.satisfiedTypes, 
                    objectDefinition.classBody.startIndex.intValue(), sameFile);
            } else if (is Tree.InterfaceDefinition declaration) {
                value interfaceDefinition = declaration;
                addSatisfiesProposals2(typeDec, changeText, data, 
                    interfaceDefinition.satisfiedTypes, 
                    if (!interfaceDefinition.typeConstraintList exists) 
                    then interfaceDefinition.interfaceBody.startIndex.intValue() 
                    else interfaceDefinition.typeConstraintList.startIndex.intValue(), sameFile);
            }
        }
    }
    
    void addConstraintSatisfiesProposals(TypeDeclaration typeParam, 
        String missingSatisfiedType, QuickFixData data, 
        TypeConstraintList? typeConstraints, Integer typeContainerBodyStartIndex,
        Boolean sameFile) {
        
        variable String? changeText = null;
        variable Integer? changeIndex = null;
        if (exists typeConstraints) {
            for (typeConstraint in typeConstraints.typeConstraints) {
                if (typeConstraint.declarationModel.equals(typeParam)) {
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
            value desc = "Add generic type constraint '``typeParam.name`` satisfies ``missingSatisfiedType``'";
            
            value region = if (sameFile) then DefaultRegion(ci, ct.size) else null;

            data.addQuickFix(desc, tfc, region);
        }
    }
    
    void addSatisfiesProposals2(TypeDeclaration typeParam, String missingSatisfiedType,
        QuickFixData data, Tree.SatisfiedTypes? typeConstraints, 
        Integer typeContainerBodyStartIndex, Boolean sameFile) {
        
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
        value desc = "Add inherited interface '``typeParam.name`` satisfies ``missingSatisfiedType``'";
        value region = if (sameFile) then DefaultRegion(changeIndex, changeText.size) else null;

        data.addQuickFix(desc, tfc, region);
    }
    
    Node? determineNode(variable Node node) {
        if (is Tree.SpecifierExpression specifierExpression = node) {
            node = specifierExpression.expression;
        }
        
        if (is Tree.Expression expression = node) {
            node = expression.term;
        }
        
        return node;
    }
    
    TypeDeclaration? determineTypeDeclaration(Node node) {
        variable TypeDeclaration? typeDec = null;
        if (is Tree.ClassOrInterface|Tree.TypeParameterDeclaration node) {
            value d = node;
            value declaration = d.declarationModel;
            if (is ClassOrInterface declaration) {
                typeDec = declaration;
            }
        } else if (is Tree.ObjectDefinition node) {
            value od = node;
            value val = od.declarationModel;
            return val.type.declaration;
        } else if (is Tree.BaseType node) {
            typeDec = node.declarationModel;
        } else if (is Tree.Term t = node) {
            if (exists type = t.typeModel) {
                typeDec = type.declaration;
            }
        }
        
        return typeDec;
    }
    
    Node? determineContainer(Tree.CompilationUnit rootNode, TypeDeclaration typeDec) {
        value fdv = object extends FindDeclarationNodeVisitor(typeDec) {
            shared actual void visit(Tree.ObjectDefinition that) {
                if (that.declarationModel.type.declaration.equals(typeDec)) {
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
    
    List<TypeParameter> determineSatisfiedTypesTypeParams(Tree.CompilationUnit rootNode, Node typeParamNode, TypeDeclaration typeDec) {
        value stTypeParams = ArrayList<TypeParameter>();
        object extends Visitor() {
            void determineSatisfiedTypesTypeParams(TypeDeclaration typeParam, Declaration? stDecl, Tree.TypeArguments? args, Node typeParamNode) {
                if (is Tree.TypeArgumentList args) {
                    value tal = args;
                    value stTypeArguments = tal.types;
                    if (stTypeArguments.contains(typeParamNode), stDecl is Generic) {
                        variable value i = 0;
                        while (i < stTypeArguments.size()) {
                            value type = stTypeArguments.get(i);
                            if (is Tree.SimpleType type) {
                                value st = type;
                                if (exists td = st.declarationModel,
                                    typeParam.equals(td)) {
                                    
                                    assert (is Generic g = stDecl);
                                    if (exists typeParameters = g.typeParameters,
                                        typeParameters.size() > i) {
                                        
                                        stTypeParams.add(typeParameters.get(i));
                                    }
                                }
                            }
                            
                            i++;
                        }
                    }
                }
            }
            
            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                determineSatisfiedTypesTypeParams(typeDec, that.declarationModel, that.typeArgumentList, typeParamNode);
            }
            
            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                super.visit(that);
                determineSatisfiedTypesTypeParams(typeDec, that.declaration, that.typeArguments, typeParamNode);
            }
            
        }.visit(rootNode);
        return stTypeParams;
    }

}
