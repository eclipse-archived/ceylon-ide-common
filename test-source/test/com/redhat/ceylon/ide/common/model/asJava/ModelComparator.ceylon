import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    FunctionOrValue,
    ModelUtil,
    TypeParameter,
    ClassOrInterface,
    Function,
    Value,
    Setter,
    Annotation,
    Class,
    Interface,
    Type,
    ParameterList,
    Parameter,
    Constructor
}
import com.redhat.ceylon.common {
    Backend
}
import com.redhat.ceylon.model.loader.model {
    LazyElement
}
import ceylon.test {
    assertNotNull,
    assertEquals,
    assertTrue,
    fail,
    assertNull
}
import ceylon.interop.java {
    javaClassFromInstance,
    javaString
}
import com.redhat.ceylon.compiler.java.codegen {
    Decl
}
import java.util {
    Comparator,
    TreeSet,
    HashMap,
    HashSet,
    Set,
    List
}
import java.lang {
    System
}
import com.redhat.ceylon.ide.common.util {
    equalsWithNulls
}


shared class ModelComparison() {
    value alreadyCompared_ = HashMap<Integer,Set<Integer>>();
    
    Boolean isUltimatelyVisible(Declaration d) {
        if (d is FunctionOrValue, (d).parameter) {
            value container = d.container;
            if (is Declaration container) {
                return isUltimatelyVisible(container);
            }
        }
        
        return d.shared;
    }
    
    shared void compareDeclarations(String name, variable Declaration theValidDeclaration, Declaration? modelDeclaration, Boolean skipAnnotations = false) {
        Declaration validDeclaration;
        if (!skipAnnotations,
            theValidDeclaration.nativeHeader) {
            value impl = ModelUtil.getNativeDeclaration(theValidDeclaration, Backend.\iJava);
            if (exists impl) {
                validDeclaration = impl;
            } else {
                validDeclaration = theValidDeclaration;
            }
        } else {
            validDeclaration = theValidDeclaration;
        }

        if (alreadyCompared(validDeclaration, modelDeclaration) || validDeclaration is LazyElement) {
            return;
        }
        
        assertNotNull(modelDeclaration, "Missing model declararion for: `` name ``");
        assert(exists modelDeclaration);
        assertNotNull(modelDeclaration.unit, "Missing Unit: `` modelDeclaration.qualifiedNameString ``");
        assert(exists modelUnit = modelDeclaration.unit);
        assertNotNull(modelDeclaration.unit.\ipackage, "Invalid Unit");
        assert(exists modelPackage = modelDeclaration.unit.\ipackage);
        if (name.startsWith("java.")) {
            return;
        }
        
        if (!(validDeclaration is FunctionOrValue) || !(validDeclaration).parameter || isUltimatelyVisible(validDeclaration)) {
            assertEquals(modelDeclaration.qualifiedNameString, validDeclaration.qualifiedNameString, name + " [name]");
        }
        
        assertEquals(modelDeclaration.shared, validDeclaration.shared, name + " [shared]");
        assertEquals(modelDeclaration.annotation, validDeclaration.annotation, name + " [annotation]");
        if (!validDeclaration.shared, !isUltimatelyVisible(validDeclaration), !(validDeclaration is TypeParameter)) {
            variable value sameType = javaClassFromInstance(validDeclaration).isAssignableFrom(javaClassFromInstance(modelDeclaration));
            sameType = sameType || validDeclaration is Value && modelDeclaration is Value;
            sameType = sameType || validDeclaration is Setter && modelDeclaration is Value;
            assertTrue(sameType, "``name`` [type] `` validDeclaration `` is not the same as ``modelDeclaration``");
            return;
        }
        
        if (!skipAnnotations) {
            compareAnnotations(validDeclaration, modelDeclaration);
        }
        
        compareContainers(validDeclaration, modelDeclaration);
        compareScopes(validDeclaration, modelDeclaration);
        if (is ClassOrInterface validDeclaration) {
            assertTrue(modelDeclaration is ClassOrInterface, name + " [ClassOrInterface]");
            assert(is ClassOrInterface modelDeclaration);
            compareClassOrInterfaceDeclarations(validDeclaration, modelDeclaration);
        } else if (Decl.isConstructor(validDeclaration)) {
            assertTrue(Decl.isConstructor(modelDeclaration), name + " [Constructor]");
        } else if (is Function validDeclaration) {
            assertTrue(modelDeclaration is Function, name + " [Method]");
            assert(is Function modelDeclaration);
            compareMethodDeclarations(validDeclaration, modelDeclaration);
        } else if (is Value | Setter validDeclaration) {
            assertTrue(modelDeclaration is Value, name + " [Attribute]");
            assert(is Value modelDeclaration);
            compareAttributeDeclarations(validDeclaration, modelDeclaration);
        } else if (is TypeParameter validDeclaration) {
            assertTrue(modelDeclaration is TypeParameter, name + " [TypeParameter]");
            assert(is TypeParameter modelDeclaration);
            compareTypeParameters(validDeclaration, modelDeclaration);
        }
    }
    
    void compareContainers(Declaration validDeclaration, Declaration modelDeclaration) {
        value name = validDeclaration.qualifiedNameString;
        value validContainer = validDeclaration.container;
        value modelContainer = modelDeclaration.container;
        if (is Declaration validContainer) {
            assertTrue(modelContainer is Declaration, name + " [Container is Declaration]");
            assert(is Declaration modelContainer);
            compareDeclarations(name + " [container]", validContainer, modelContainer);
        } else {
            assertTrue(modelContainer is Declaration == false, name + " [Container is not Declaration]");
        }
    }
    
    void compareScopes(Declaration validDeclaration, Declaration modelDeclaration) {
        value name = validDeclaration.qualifiedNameString;
        value validContainer = validDeclaration.container;
        value modelContainer = modelDeclaration.container;
        if (is Declaration validContainer) {
            assertTrue(modelContainer is Declaration, name + " [Scope is Declaration]");
            assert(is Declaration modelContainer);
            compareDeclarations(name + " [scope]", validContainer, modelContainer);
        } else {
            assertTrue(modelContainer is Declaration == false, name + " [Scope is not Declaration]");
        }
    }
    
    void compareAnnotations(Declaration validDeclaration, Declaration modelDeclaration) {
        if (is Setter validDeclaration) {
            return;
        }
        
        value name = validDeclaration.qualifiedNameString;
        value cmp = object satisfies Comparator<Annotation> {
            shared actual Integer compare(Annotation a, Annotation b) {
                return javaString(a.name).compareTo((b.name));
            }
            shared actual Boolean equals(Object that) => false;
        };
        
        value validAnnotations = TreeSet<Annotation>(cmp);
        validAnnotations.addAll(validDeclaration.annotations);
        value modelAnnotations = TreeSet<Annotation>(cmp);
        modelAnnotations.addAll(modelDeclaration.annotations);
        assertEquals(modelAnnotations.size(), validAnnotations.size(), name + " [annotation count]");
        value validIter = validAnnotations.iterator();
        value modelIter = modelAnnotations.iterator();
        while (validIter.hasNext() || modelIter.hasNext()) {
            compareAnnotation(name, validIter.next(), modelIter.next());
        }
    }
    
    void compareAnnotation(String element, Annotation validAnnotation, Annotation modelAnnotation) {
        assertEquals(modelAnnotation.name, validAnnotation.name, element + " [annotation name]");
        value name = element + "@" + validAnnotation.name;
        value validPositionalArguments = validAnnotation.positionalArguments;
        value modelPositionalArguments = modelAnnotation.positionalArguments;
        assertEquals(modelPositionalArguments.size(), validPositionalArguments.size(), name + " [annotation argument size]");
        variable value i = 0;
        while (i < validPositionalArguments.size()) {
            assertEquals(modelPositionalArguments.get(i), validPositionalArguments.get(i), "``name`` [annotation argument `` i ``]");
            i++;
        }
        
        value validNamedArguments = validAnnotation.namedArguments;
        value modelNamedArguments = modelAnnotation.namedArguments;
        assertEquals(modelNamedArguments.size(), validNamedArguments.size(), name + " [annotation named argument size]");
        for (validEntry in validNamedArguments.entrySet()) {
            value modelValue = modelNamedArguments.get(validEntry.key);
            assertEquals(modelValue, validEntry.\ivalue, "``name`` [annotation named argument ``validEntry.key``]");
        }
    }
    
    Boolean alreadyCompared(Declaration validDeclaration, Declaration? modelDeclaration) {
        value hashCode = System.identityHashCode(modelDeclaration);
        variable value comparedDeclarations = alreadyCompared_.get(hashCode);
        if (!comparedDeclarations exists) {
            comparedDeclarations = HashSet<Integer>();
            alreadyCompared_.put(hashCode, comparedDeclarations);
        }
        
        return !comparedDeclarations.add(System.identityHashCode(validDeclaration));
    }
    
    void compareTypeParameters(TypeParameter validDeclaration, TypeParameter modelDeclaration) {
        value name = validDeclaration.container.string + "<" + validDeclaration.name + ">";
        assertEquals(modelDeclaration.contravariant, validDeclaration.contravariant, name + " [Contravariant]");
        assertEquals(modelDeclaration.covariant, validDeclaration.covariant, name + " [Covariant]");
        Boolean validDeclIsSelfType = validDeclaration.selfTypedDeclaration exists;
        Boolean modelDeclIsSelfType = modelDeclaration.selfTypedDeclaration exists ;
        assertEquals(modelDeclIsSelfType, validDeclIsSelfType, name + " [SelfType]");
        assertEquals(modelDeclaration.defaulted, validDeclaration.defaulted, name + " [Defaulted]");
        if (validDeclaration.declaration exists, modelDeclaration.declaration exists) {
            compareDeclarations(name + " [type param]", validDeclaration.declaration, modelDeclaration.declaration);
        } else if (!(!validDeclaration.declaration exists && !modelDeclaration.declaration exists)) {
            fail("[Declaration] one has declaration the other not");
        }
        
        if (validDeclaration.selfTypedDeclaration exists, modelDeclaration.selfTypedDeclaration exists) {
            compareDeclarations(name + " [type param self typed]", validDeclaration.selfTypedDeclaration, modelDeclaration.selfTypedDeclaration);
        } else if (!(!validDeclaration.selfTypedDeclaration exists && !modelDeclaration.selfTypedDeclaration exists)) {
            fail("[SelfType] one has self typed declaration the other not");
        }
        
        if (validDeclaration.defaultTypeArgument exists, modelDeclaration.defaultTypeArgument exists) {
            compareDeclarations(name + " [type param default]", validDeclaration.defaultTypeArgument.declaration, modelDeclaration.defaultTypeArgument.declaration);
        } else if (!(!validDeclaration.defaultTypeArgument exists && !modelDeclaration.defaultTypeArgument exists)) {
            fail("[DefaultTypeArgument] one has default type argument the other not");
        }
        
        compareSatisfiedTypes(name, validDeclaration.satisfiedTypes, modelDeclaration.satisfiedTypes);
        compareCaseTypes(name, validDeclaration.caseTypes, modelDeclaration.caseTypes);
    }
    
    void compareClassOrInterfaceDeclarations(ClassOrInterface validDeclaration, ClassOrInterface modelDeclaration) {
        value name = validDeclaration.qualifiedNameString;
        assertEquals(modelDeclaration.abstract, validDeclaration.abstract, name + " [abstract]");
        assertEquals(modelDeclaration.formal, validDeclaration.formal, name + " [formal]");
        assertEquals(modelDeclaration.actual, validDeclaration.actual, name + " [actual]");
        assertEquals(modelDeclaration.default, validDeclaration.default, name + " [default]");
        assertEquals(modelDeclaration.sealed, validDeclaration.sealed, name + " [sealed]");
        assertEquals(modelDeclaration.\idynamic, validDeclaration.\idynamic, name + " [dynamic]");
        if (!validDeclaration.extendedType exists) {
            assertTrue(!modelDeclaration.extendedType exists, name + " [null supertype]");
        } else {
            compareDeclarations(name + " [supertype]", validDeclaration.extendedType.declaration, if (!modelDeclaration.extendedType exists) then null else modelDeclaration.extendedType.declaration);
        }
        
        compareSatisfiedTypes(name, validDeclaration.satisfiedTypes, modelDeclaration.satisfiedTypes);
        compareCaseTypes(name, validDeclaration.caseTypes, modelDeclaration.caseTypes);
        compareTypeParametersWithName(name, validDeclaration.typeParameters, modelDeclaration.typeParameters);
        if (is Class validDeclaration) {
            assertTrue(modelDeclaration is Class, name + " [is class]");
            assert(is Class modelDeclaration);
            compareSelfTypes(validDeclaration, modelDeclaration, name);
            compareParameterLists(validDeclaration.qualifiedNameString, validDeclaration.parameterLists, modelDeclaration.parameterLists);
            assertEquals(modelDeclaration.final, validDeclaration.final, name + " [is final]");
        } else {
            assertTrue(modelDeclaration is Interface, name + " [is interface]");
        }
        
        for (validMember in validDeclaration.members) {
            if (!validMember.shared) {
                continue;
            }
            
            value modelMember = lookupMember(modelDeclaration, validMember);
            assertNotNull(modelMember, "``javaClassFromInstance(validMember).simpleName`` ``validMember.qualifiedNameString`` [``validMember.declarationKind``] not found in loaded model");
            assert(exists modelMember);
            compareDeclarations(modelMember.qualifiedNameString, validMember, modelMember);
        }
        
        for (modelMember in modelDeclaration.members) {
            if (!modelMember.shared) {
                continue;
            }
            
            variable value validMember = lookupMember(validDeclaration, modelMember) else null;
            if (!validMember exists, validDeclaration.native) {
                value hdr = ModelUtil.getNativeHeader(validDeclaration);
                if (is ClassOrInterface hdr) {
                    validMember = lookupMember(hdr, modelMember);
                }
            }
            
            assertNotNull(validMember, modelMember.qualifiedNameString + " [extra member] encountered in loaded model");
        }
    }
    
    void compareCaseTypes(String name, List<Type>? validTypeDeclarations, List<Type>? modelTypeDeclarations) {
        if (exists validTypeDeclarations) {
            assertNotNull(modelTypeDeclarations, name + " [null case types]");
        } else {
            assertNull(modelTypeDeclarations, name + " [non-null case types]");
            return;
        }
        assert(exists modelTypeDeclarations);
        
        assertEquals(modelTypeDeclarations.size(), validTypeDeclarations.size(), name + " [case types count]");
        variable value i = 0;
        while (i < validTypeDeclarations.size()) {
            value validTypeDeclaration = validTypeDeclarations.get(i).declaration;
            value modelTypeDeclaration = modelTypeDeclarations.get(i).declaration;
            compareDeclarations(name + " [case types]", validTypeDeclaration, modelTypeDeclaration);
            i++;
        }
    }
    
    void compareSelfTypes(Class validDeclaration, Class modelDeclaration, String name) {
        if (!validDeclaration.selfType exists) {
            assertTrue(!modelDeclaration.selfType exists, name + " [null self type]");
        } else {
            value validSelfType = validDeclaration.selfType;
            value modelSelfType = modelDeclaration.selfType;
            assertNotNull(modelSelfType, name + " [non-null self type]");
            compareDeclarations(name + " [non-null self type]", validSelfType.declaration, modelSelfType.declaration);
        }
    }
    
    Declaration? lookupMember(ClassOrInterface container, Declaration referenceMember) {
        value name = referenceMember.name else null;
        for (member in container.members) {
            if ((referenceMember is Constructor && member is FunctionOrValue) || (referenceMember is FunctionOrValue && member is Constructor)) {
                continue;
            }
            
            if (!name exists, !member.name exists) {
                return member;
            } else if (member.name exists, equalsWithNulls(member.name,name)) {
                if (Decl.isValue(referenceMember), (member is Class || (member is Value && (member).parameter))) {
                    continue;
                }
                
                if ((referenceMember is Class || referenceMember is Value && (referenceMember).parameter), Decl.isValue(member)) {
                    continue;
                }
                
                return member;
            }
        }
        
        return null;
    }
    
    void compareSatisfiedTypes(String name, List<Type> validTypeDeclarations, List<Type> modelTypeDeclarations) {
        assertEquals(modelTypeDeclarations.size(), validTypeDeclarations.size(), name + " [Satisfied types count]");
        variable value i = 0;
        while (i < validTypeDeclarations.size()) {
            value validTypeDeclaration = validTypeDeclarations.get(i).declaration;
            value modelTypeDeclaration = modelTypeDeclarations.get(i).declaration;
            compareDeclarations(name + " [Satisfied types]", validTypeDeclaration, modelTypeDeclaration);
            i++;
        }
    }
    
    void compareParameterLists(String name, List<ParameterList> validParameterLists, List<ParameterList> modelParameterLists) {
        assertEquals(modelParameterLists.size(), validParameterLists.size(), name + " [param lists count]");
        variable value i = 0;
        while (i < validParameterLists.size()) {
            value validParameterList = validParameterLists.get(i).parameters;
            value modelParameterList = modelParameterLists.get(i).parameters;
            compareParameterList(name, i, validParameterList, modelParameterList);
            i++;
        }
    }
    
    void compareParameterList(String name, Integer i, List<Parameter> validParameterList, List<Parameter> modelParameterList) {
        assertEquals(modelParameterList.size(), validParameterList.size(), "``name`` [param lists ``i`` count]");
        variable value p = 0;
        while (p < validParameterList.size()) {
            value validParameter = validParameterList.get(p);
            value modelParameter = modelParameterList.get(p);
            assertEquals(modelParameter.name, validParameter.name, name + " [param " + validParameter.name + " name]");
            assertEquals(modelParameter.declaredAnything, validParameter.declaredAnything, name + " [param " + validParameter.name + " declaredAnything]");
            assertEquals(modelParameter.sequenced, validParameter.sequenced, name + " [param " + validParameter.name + " sequenced]");
            assertEquals(modelParameter.defaulted, validParameter.defaulted, name + " [param " + validParameter.name + " defaulted]");
            compareDeclarations("``name`` [param ``i``, ``p``]", validParameter.model, modelParameter.model, i > 0);
            p++;
        }
    }
    
    void compareMethodDeclarations(Function validDeclaration, Function modelDeclaration) {
        value name = validDeclaration.qualifiedNameString;
        assertEquals(modelDeclaration.formal, validDeclaration.formal, name + " [formal]");
        assertEquals(modelDeclaration.actual, validDeclaration.actual, name + " [actual]");
        assertEquals(modelDeclaration.default, validDeclaration.default, name + " [default]");
        value validParameterLists = validDeclaration.parameterLists;
        value modelParameterLists = modelDeclaration.parameterLists;
        if (validParameterLists.size() == 1) {
            assertEquals(modelDeclaration.declaredVoid, validDeclaration.declaredVoid, name + " [declaredVoid]");
        }
        
        compareParameterLists(name, validParameterLists, modelParameterLists);
        compareDeclarations(name + " [return type]", validDeclaration.type.declaration, modelDeclaration.type.declaration);
        compareTypeParametersWithName(name, validDeclaration.typeParameters, modelDeclaration.typeParameters);
    }
    
    void compareTypeParametersWithName(String name, List<TypeParameter> validTypeParameters, List<TypeParameter> modelTypeParameters) {
        assertEquals(modelTypeParameters.size(), validTypeParameters.size(), name + " [type parameter count]");
        variable value i = 0;
        while (i < validTypeParameters.size()) {
            value validTypeParameter = validTypeParameters.get(i);
            value modelTypeParameter = modelTypeParameters.get(i);
            compareDeclarations("``name`` [type param ``i``]", validTypeParameter, modelTypeParameter);
            i++;
        }
    }
    
    void compareAttributeDeclarations(FunctionOrValue validDeclaration, Value modelDeclaration) {
        if (is Setter validDeclaration) {
            return;
        }
        
        value name = validDeclaration.qualifiedNameString;
        if (!validDeclaration.parameter) {
            assertEquals(modelDeclaration.variable, validDeclaration.variable, name + " [variable]");
        }
        
        assertEquals(modelDeclaration.formal, validDeclaration.formal, name + " [formal]");
        assertEquals(modelDeclaration.actual, validDeclaration.actual, name + " [actual]");
        assertEquals(modelDeclaration.default, validDeclaration.default, name + " [default]");
        assertEquals(modelDeclaration.late, validDeclaration.late, name + " [late]");
        if (compareTransientness(validDeclaration)) {
            assertEquals(modelDeclaration.transient, validDeclaration.transient, name + " [transient]");
        }
        
        compareDeclarations(name + " [type]", validDeclaration.type.declaration, modelDeclaration.type.declaration);
    }
    
    Boolean compareTransientness(FunctionOrValue validDeclaration) {
        return true;
    }
}
