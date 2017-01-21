import ceylon.collection {
    naturalOrderTreeSet
}
import ceylon.interop.java {
    CeylonList,
    javaClassFromInstance,
    CeylonIterable
}
import ceylon.test {
    assertEquals
}

import com.redhat.ceylon.ide.common.util {
    equalsWithNulls
}
import com.redhat.ceylon.model.loader.mirror {
    ClassMirror,
    PackageMirror,
    TypeParameterMirror,
    MethodMirror,
    FieldMirror,
    VariableMirror,
    TypeMirror,
    AnnotatedMirror,
    TypeKind,
    AccessibleMirror,
    AnnotationMirror
}

import java.lang {
    System,
    JClass=Class
}
import java.util {
    HashMap,
    Set,
    HashSet,
    JList=List
}
import com.redhat.ceylon.model.loader.impl.reflect.mirror {
    ReflectionType,
    ReflectionClass
}

TypeKind? typeKind(TypeMirror tm) {
    try {
        return tm.kind;
    } catch(Exception e) {
        return null;
    }
}

Boolean typeHasQualifiedName(TypeMirror tm) => let(kind = typeKind(tm)) 
equalsWithNulls(kind, TypeKind.declared) || 
        equalsWithNulls(kind, TypeKind.typevar);

String typeQualifiedName(TypeMirror typeMirror) => 
        if (is ReflectionType typeMirror,
    exists declaredClass = typeMirror.declaredClass) 
then declaredClass.qualifiedName 
else typeMirror.qualifiedName;

String typeString(TypeMirror? tm) {
    if (!exists tm) {
        return "'nullTypeMirror'";
    }
    
    switch(kind = typeKind(tm))
    case(is Null) {
        return "<unresolved>";
    }
    case(TypeKind.declared | TypeKind.typevar) {
        return "``typeQualifiedName(tm)``<`` ",".join {
            for (ta in tm.typeArguments) typeString(ta)
        } ``>";
    }
    case(TypeKind.wildcard) {
        return "[lower bound]``typeString(tm.lowerBound)`` - [upper bound]``typeString(tm.upperBound)``";
    }
    case(TypeKind.array) {
        return "``typeString(tm.componentType)``[]";
    }
    case(TypeKind.null) {
        return "'null'";
    }
    case(TypeKind.\ivoid) {
        return "'void'";
    }
    case(TypeKind.error) {
        return "'error'";
    }
    else {
        if (kind.primitive) {
            return kind.name().lowercased;
        }
        else {
            return "'unknown'";
        }
    }
}

shared class MirrorComparison() {
    value alreadyCompared_ = HashMap<Integer,Set<Integer>>();
    
    Boolean alreadyCompared(Object expectedValue, Object? actualValue) {
        function buildHashCode(Object? obj) {
            if (is ClassMirror obj) {
                return "[Class] `` obj.qualifiedName ``".hash;
            } else if (is TypeMirror obj) {
                return typeString(obj).hash;
            } else{
                return System.identityHashCode(obj);
            }
        }

        value hashCode = buildHashCode(actualValue);
        variable value comparedValues = alreadyCompared_.get(hashCode);
        if (!comparedValues exists) {
            comparedValues = HashSet<Integer>();
            alreadyCompared_.put(hashCode, comparedValues);
        }
        
        return !comparedValues.add(buildHashCode(expectedValue));
    }
    
    shared alias AnyMirror => ClassMirror | MethodMirror | FieldMirror | VariableMirror | TypeMirror | PackageMirror | TypeParameterMirror;
    
    function mirrorName(AnyMirror? m) =>
            if (is ClassMirror m) then m.qualifiedName
    else if (is MethodMirror m) then (m.constructor then "<init>" else (m.staticInit then "<clinit>" else m.name else "<init>"))
    else if(is <FieldMirror | VariableMirror> m) then m.name
    else if (is TypeParameterMirror m) then m.name
    else if (is PackageMirror m) then m.qualifiedName
    else if (is TypeMirror m) then typeString(m)
    else "<null>";

    shared void compareAnyMirror(
        AnyMirror? expectedMirror, 
        AnyMirror? actualMirror,
        String elementDescription = "") {
        
        if(is ClassMirror expectedMirror, is ClassMirror actualMirror) {
            compareClassMirrors(expectedMirror, actualMirror);
        } else if(is MethodMirror expectedMirror, is MethodMirror actualMirror) {
            compareMethodMirrors(expectedMirror, actualMirror);
        } else if(is FieldMirror expectedMirror, is FieldMirror actualMirror) {
            compareFieldMirrors(expectedMirror, actualMirror);
        } else if(is VariableMirror expectedMirror, is VariableMirror actualMirror) {
            compareVariableMirrors(expectedMirror, actualMirror);
        } else if(is TypeMirror expectedMirror, is TypeMirror actualMirror) {
            compareTypeMirrors(expectedMirror, actualMirror);
        } else if(is TypeParameterMirror expectedMirror, is TypeParameterMirror actualMirror) {
            compareTypeParameterMirrors(expectedMirror, actualMirror);
        } else if(is PackageMirror expectedMirror, is PackageMirror actualMirror) {
            comparePackageMirrors(expectedMirror, actualMirror);
        } else {
            assertEquals {
                actual = mirrorName(actualMirror);
                expected = mirrorName(expectedMirror);
                message = "Mirrors don't match: ``
                if (! expectedMirror exists && actualMirror exists) then "actual mirror should NOT exist"
                else if (expectedMirror exists && !actualMirror exists) then "actual mirror is missing"
                else "unexpected situation" ``
                `` elementDescription.empty then "" else  " for " + elementDescription ``";
            };
        }
    }
    
    void compareAnnotationValues(Object? expectedValue, Object? actualValue, String field, String annotationName, String elementName, AnnotationMirror? expectedAnnotation, AnnotationMirror? actualAnnotation) {
        if (is AnnotationMirror? actualValue, is AnnotationMirror? expectedValue) {
            suppressWarnings("expressionTypeNothing")
            value embeddedAnnotation = switch(annotationName)
            case("com.redhat.ceylon.compiler.java.metadata.Members")
                "com.redhat.ceylon.compiler.java.metadata.Member"
            else nothing;
            compareAnnotations(expectedValue, actualValue, embeddedAnnotation, "Field `` field `` of annotation `` annotationName `` on `` elementName ``");
        } else if (is TypeMirror actualValue, is TypeMirror expectedValue) {
            compareTypeMirrors(expectedValue, actualValue);
        } else if (is JList<out Anything> actualValue, is JList<out Anything> expectedValue) {
            assertEquals {
                actual = actualValue.size();
                expected = expectedValue.size();
                message = "Field `` field `` of annotation `` annotationName `` on `` elementName `` don't have the samenames of embedded annotations";
            };
            for (pair in zipPairs(CeylonIterable(expectedValue), CeylonIterable(actualValue))) {
                compareAnnotationValues(pair[0] of Object?, pair[1] of Object?, field, annotationName, elementName, expectedAnnotation, actualAnnotation);
            }
        }
        else {
            assertEquals {
                actual = actualValue;
                expected = expectedValue;
                message = if (exists actualAnnotation, exists expectedAnnotation) 
                then "Field `` field `` of annotation `` annotationName `` differ on `` elementName ``"
                else "Annotation `` annotationName `` should `` 
                if (!exists expectedAnnotation) then "not" else "" 
                `` exist on `` elementName ``";
            };
        }
    }
    
    void compareAnnotations(AnnotationMirror? expectedAnnotation, AnnotationMirror? actualAnnotation, String annotationName, String elementName) {
        if(true) {
            return;
        } else {
            value annotationClass = JClass.forName(annotationName);
            for (m in annotationClass.declaredMethods) {
                value field = m.name;
                value defaultValue = m.defaultValue;
                value actualValue = actualAnnotation?.getValue(field) else defaultValue;
                value expectedValue = expectedAnnotation?.getValue(field) else defaultValue;
                compareAnnotationValues(actualValue, expectedValue, field, annotationName, elementName, actualAnnotation, expectedAnnotation);
            }
        }
    }
    
    void compareAnnotationLists(AnnotatedMirror expectedMirror, AnnotatedMirror actualMirror, String elementName) {
        value allAnnotationNames = naturalOrderTreeSet ({ *sort { for (an in expectedMirror.annotationNames) an.string}}
            .chain { *sort { for (an in actualMirror.annotationNames) an.string}});

        for (annotationName in allAnnotationNames) {
            value expectedAnnotation = expectedMirror.getAnnotation(annotationName);
            value actualAnnotation = actualMirror.getAnnotation(annotationName);
            compareAnnotations(expectedAnnotation, actualAnnotation, annotationName, elementName);
        }
    }
    
    function shouldSkipPrivateMember(AccessibleMirror expectedMirror) => 
            ! expectedMirror.public && ! expectedMirror.protected && ! expectedMirror.defaultAccess;

    function shouldSkipIgnoredMember(AnnotatedMirror expectedMirror) => 
            expectedMirror.getAnnotation("com.redhat.ceylon.compiler.java.metadata.Ignore") exists;
        
    void compareClassMirrors(ClassMirror expectedMirror, ClassMirror actualMirror) {
        if (actualMirror is ReflectionClass) {
            return;
        }
            
        if (shouldSkipPrivateMember(expectedMirror)) {
            return;
        }
        
        
        if (alreadyCompared(expectedMirror, actualMirror)) {
            return;
        }
        
        
        value elementName = "class mirror `` expectedMirror.qualifiedName ``";

        {
            `ClassMirror.qualifiedName`,
            `ClassMirror.name`,
            `ClassMirror.flatName`,
            `ClassMirror.public`,
            `ClassMirror.protected`,
            `ClassMirror.defaultAccess`,
            `ClassMirror.static`,
            `ClassMirror.final`,
            `ClassMirror.enum`,
            `ClassMirror.abstract`,
            `ClassMirror.annotationType`,
            `ClassMirror.anonymous`,
            `ClassMirror.\iinterface`,
            `ClassMirror.innerClass`,
            `ClassMirror.localClass`,
/*            `ClassMirror.ceylonToplevelAttribute`,
            `ClassMirror.ceylonToplevelMethod`,
            `ClassMirror.ceylonToplevelObject`, */
            `ClassMirror.javaSource`,
            `ClassMirror.loadedFromSource`
        }.each((val) => let(apply = val.bind)
            assertEquals {
            actual = apply(actualMirror).get();
            expected = apply(expectedMirror).get();
            message = "attribute `` val.declaration.name `` differ on `` elementName ``";
        });

        {
            `ClassMirror.\ipackage`,
            `ClassMirror.enclosingClass`,
            `ClassMirror.enclosingMethod`,
            `ClassMirror.superclass`
        }.each((val) => let(apply = val.bind)
            compareAnyMirror {
                expectedMirror = apply(expectedMirror).get();
                actualMirror = apply(actualMirror).get();
                elementDescription = "`` elementName ``.``val.declaration.name``";
            });
    
        {
            `ClassMirror.directFields`,
            `ClassMirror.directInnerClasses`,
            `ClassMirror.directMethods`,
            `ClassMirror.interfaces`,
            `ClassMirror.typeParameters`
        }.each((val) {
            value apply = val.bind;
            variable List<AnyMirror?> expectedMirrors = CeylonList(apply(expectedMirror).get())
                    .filter((m) => if (is AnnotatedMirror m, shouldSkipIgnoredMember(m)) then false else true)
                    .sort(byIncreasing(mirrorName));
            if (val.declaration.name.startsWith("direct")) {
                expectedMirrors = expectedMirrors.filter((m) => 
                    if (is AccessibleMirror m, shouldSkipPrivateMember(m)) then false else true).sequence();
            }
            
            variable List<AnyMirror?> actualMirrors = CeylonList(apply(actualMirror).get())
                    .sort(byIncreasing(mirrorName));
            value sizeDiff = expectedMirrors.size - actualMirrors.size;
            if (sizeDiff != 0) {
                value patch = Array.ofSize(sizeDiff, null);
                if (sizeDiff > 0) {
                    actualMirrors = actualMirrors.patch(patch);
                }
                else {
                    expectedMirrors = expectedMirrors.patch(patch);
                }
            }
            zipPairs(expectedMirrors, actualMirrors)
                    .map((args)=>[args[0], args[1], "`` elementName ``.``val.declaration.name``"])
                    .each(unflatten(compareAnyMirror));
        });
        
        compareAnnotationLists(expectedMirror, actualMirror, elementName);
    }
    
    void compareMethodMirrors(MethodMirror expectedMirror, MethodMirror actualMirror) {
        if (alreadyCompared(expectedMirror, actualMirror)) {
            return;
        }
        
        if (shouldSkipPrivateMember(expectedMirror) || shouldSkipIgnoredMember(expectedMirror)) {
            return;
        }
        
        value elementName = "method mirror `` 
            (expectedMirror.enclosingClass?.qualifiedName?.plus(".") else "") + expectedMirror.name ``()";
        
        {
            !(expectedMirror.constructor || expectedMirror.staticInit) then 
            `MethodMirror.name`,
            `MethodMirror.constructor`,
            `MethodMirror.abstract`,
            `MethodMirror.declaredVoid`,
             !expectedMirror.constructor then `MethodMirror.default`,
            `MethodMirror.defaultMethod`,
            `MethodMirror.final`,
            `MethodMirror.static`,
            `MethodMirror.staticInit`,
            `MethodMirror.variadic`,
            `MethodMirror.defaultAccess`,
            `MethodMirror.protected`,
            `MethodMirror.public`
        }.coalesced.each((val) => let(apply = val.bind)
            assertEquals {
            actual = apply(actualMirror).get();
            expected = apply(expectedMirror).get();
            message = "attribute `` val.declaration.name `` differ on `` elementName ``";
        });
        
        {
            `MethodMirror.returnType`,
            `MethodMirror.enclosingClass`            
        }.each((val) => let(apply = val.bind)
            compareAnyMirror {
                expectedMirror = apply(expectedMirror).get();
                actualMirror = apply(actualMirror).get();
                elementDescription = "`` elementName ``.``val.declaration.name``";
            });
        
        {
            `MethodMirror.parameters`,
            `MethodMirror.typeParameters`
        }.each((val) {
            value apply = val.bind;
            variable List<AnyMirror?> expectedMirrors = CeylonList(apply(expectedMirror).get())
                    .sort(byIncreasing(mirrorName));
            variable List<AnyMirror?> actualMirrors = CeylonList(apply(actualMirror).get())
                    .sort(byIncreasing(mirrorName));
            value sizeDiff = expectedMirrors.size - actualMirrors.size;
            if (sizeDiff != 0) {
                value patch = Array.ofSize(sizeDiff, null);
                if (sizeDiff > 0) {
                    actualMirrors = actualMirrors.patch(patch);
                }
                else {
                    expectedMirrors = expectedMirrors.patch(patch);
                }
            }
            zipPairs(expectedMirrors, actualMirrors)
                    .map((args)=>[args[0], args[1], "`` elementName ``.``val.declaration.name``"])
                    .each(unflatten(compareAnyMirror));
        });
        
        compareAnnotationLists(expectedMirror, actualMirror, elementName);
    }

    void compareFieldMirrors(FieldMirror expectedMirror, FieldMirror actualMirror) {
        if (alreadyCompared(expectedMirror, actualMirror)) {
            return;
        }

        if (shouldSkipPrivateMember(expectedMirror) || shouldSkipIgnoredMember(expectedMirror)) {
            return;
        }

        if (expectedMirror.getAnnotation("com.redhat.ceylon.compiler.java.metadata.Ignore") exists) {
            return;
        }
        
        value elementName = "field mirror `` expectedMirror.name ``";
        
        {
            `FieldMirror.name`,
            `FieldMirror.public`,
            `FieldMirror.protected`,
            `FieldMirror.defaultAccess`,
            `FieldMirror.final`,
            `FieldMirror.static`
        }.each((val) => let(apply = val.bind)
            assertEquals {
            actual = apply(actualMirror).get();
            expected = apply(expectedMirror).get();
            message = "attribute `` val.declaration.name `` differ on `` elementName ``";
        });
        
        {
            `FieldMirror.type`
        }.each((val) => let(apply = val.bind)
            compareAnyMirror {
                expectedMirror = apply(expectedMirror).get();
                actualMirror = apply(actualMirror).get();
                elementDescription = "`` elementName ``.``val.declaration.name``";
            });
        
        compareAnnotationLists(expectedMirror, actualMirror, elementName);
    }
    
    void compareVariableMirrors(VariableMirror expectedMirror, VariableMirror actualMirror) {
        if (alreadyCompared(expectedMirror, actualMirror)) {
            return;
        }
        
        value elementName = "variable mirror `` expectedMirror.name ``";
        
        {
            (expectedMirror.name != "unknown") then
            `VariableMirror.name`
        }.coalesced.each((val) => let(apply = val.bind)
            assertEquals {
            actual = apply(actualMirror).get();
            expected = apply(expectedMirror).get();
            message = "attribute `` val.declaration.name `` differ on `` elementName ``";
        });
        
        {
            `VariableMirror.type`
        }.each((val) => let(apply = val.bind)
            compareAnyMirror {
                expectedMirror = apply(expectedMirror).get();
                actualMirror = apply(actualMirror).get();
                elementDescription = "`` elementName ``.``val.declaration.name``";
            });
        
        compareAnnotationLists(expectedMirror, actualMirror, elementName);
    }

    void comparePackageMirrors(PackageMirror expectedMirror, PackageMirror actualMirror) =>
        assertEquals {
                actual = actualMirror.qualifiedName;
                expected = expectedMirror.qualifiedName;
                message = "packages differ";
        };

    
    void compareTypeMirrors(TypeMirror expectedMirror, TypeMirror actualMirror) {
        if (alreadyCompared(expectedMirror, actualMirror)) {
            return;
        }
        
        if (javaClassFromInstance(expectedMirror) == javaClassFromInstance(actualMirror)
            && typeString(expectedMirror) == typeString(actualMirror)) {
            return;
        }
        
        value expectedKind = typeKind(expectedMirror);
        value hasQualifiedName = typeHasQualifiedName(expectedMirror);
        
        value elementName = "type mirror `` hasQualifiedName then typeQualifiedName(expectedMirror) else expectedMirror.string ``";
        
        {
            `TypeMirror.kind`,
            `TypeMirror.primitive`,
             hasQualifiedName then `TypeMirror.qualifiedName`,
            `TypeMirror.raw`
        }.coalesced.each((val) => let(apply = val.bind)
            assertEquals {
            actual = apply(actualMirror).get();
            expected = if (val.declaration.name == "qualifiedName") 
            // This special case is there because `qualifiedName` impmementation is wrong on ReflectionType
            then typeQualifiedName(expectedMirror) 
            else apply(expectedMirror).get();
            message = "attribute `` val.declaration.name `` differ on `` elementName ``";
        });
        
        {
            equalsWithNulls(expectedKind, TypeKind.array) then
            `TypeMirror.componentType`,
            equalsWithNulls(expectedKind,TypeKind.declared) ||
                    equalsWithNulls(expectedKind,TypeKind.typevar) then
            `TypeMirror.declaredClass`,
            equalsWithNulls(expectedKind, TypeKind.wildcard) then
            `TypeMirror.lowerBound`,
            equalsWithNulls(expectedKind, TypeKind.wildcard) then
            `TypeMirror.upperBound`,
            `TypeMirror.qualifyingType`,
            `TypeMirror.typeParameter`
        }.coalesced.each((val) => let(apply = val.bind)
            compareAnyMirror {
                expectedMirror = apply(expectedMirror).get();
                actualMirror = apply(actualMirror).get();
                elementDescription = "`` elementName ``.``val.declaration.name``";
            });
        
        {
            `TypeMirror.typeArguments`
        }.each((val) {
            value apply = val.bind;
            variable List<AnyMirror?> expectedMirrors = CeylonList(apply(expectedMirror).get())
                    .sort(byIncreasing(mirrorName));
            variable List<AnyMirror?> actualMirrors = CeylonList(apply(actualMirror).get())
                    .sort(byIncreasing(mirrorName));
            value sizeDiff = expectedMirrors.size - actualMirrors.size;
            if (sizeDiff != 0) {
                value patch = Array.ofSize(sizeDiff, null);
                if (sizeDiff > 0) {
                    actualMirrors = actualMirrors.patch(patch);
                }
                else {
                    expectedMirrors = expectedMirrors.patch(patch);
                }
            }
            zipPairs(expectedMirrors, actualMirrors)
                    .map((args)=>[args[0], args[1], "`` elementName ``.``val.declaration.name``"])
                    .each(unflatten(compareAnyMirror));
        });
    }

    void compareTypeParameterMirrors(TypeParameterMirror expectedMirror, TypeParameterMirror actualMirror) {
        if (alreadyCompared(expectedMirror, actualMirror)) {
            return;
        }
        
        value elementName = "type parameter mirror `` expectedMirror.name ``";
        
        {
            `TypeParameterMirror.name`
        }.each((val) => let(apply = val.bind)
            assertEquals {
            actual = apply(actualMirror).get();
            expected = apply(expectedMirror).get();
            message = "attribute `` val.declaration.name `` differ on `` elementName ``";
        });
        
        {
            `TypeParameterMirror.bounds`
        }.each((val) {
            value apply = val.bind;
            variable List<AnyMirror?> expectedMirrors = CeylonList(apply(expectedMirror).get())
                    .sort(byIncreasing(mirrorName));
            variable List<AnyMirror?> actualMirrors = CeylonList(apply(actualMirror).get())
                    .sort(byIncreasing(mirrorName));
            value sizeDiff = expectedMirrors.size - actualMirrors.size;
            if (sizeDiff != 0) {
                value patch = Array.ofSize(sizeDiff, null);
                if (sizeDiff > 0) {
                    actualMirrors = actualMirrors.patch(patch);
                }
                else {
                    expectedMirrors = expectedMirrors.patch(patch);
                }
            }
            zipPairs(expectedMirrors, actualMirrors)
                    .map((args)=>[args[0], args[1], "`` elementName ``.``val.declaration.name``"])
                    .each(unflatten(compareAnyMirror));
        });
    }
}
