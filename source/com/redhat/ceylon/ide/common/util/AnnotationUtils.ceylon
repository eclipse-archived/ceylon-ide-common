import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.model.typechecker.model {
    Annotation,
    Declaration,
    Package,
    TypeDeclaration,
    Module,
    Referenceable,
    Annotated
}
import com.redhat.ceylon.model.loader.mirror {
    AnnotatedMirror
}
import com.redhat.ceylon.model.loader.model {
    JavaMethod,
    LazyInterfaceAlias,
    LazyFunction,
    LazyTypeAlias,
    LazyInterface,
    LazyValue,
    LazyClassAlias,
    JavaBeanValue,
    LazyClass
}

shared Annotation? findAnnotationModel(Annotated&Referenceable annotated, String name) => 
        CeylonIterable(annotated.annotations).find((ann) => ann.name == name);

shared AnnotatedMirror? toAnnotatedMirror(Annotated&Referenceable annotated) =>
        switch(annotated)
case(is LazyClass) annotated.classMirror
case(is LazyClassAlias) annotated.classMirror
case(is LazyInterface) annotated.classMirror
case(is LazyInterfaceAlias) annotated.classMirror
case(is LazyValue) annotated.classMirror
case(is LazyTypeAlias) annotated.classMirror
case(is LazyFunction) annotated.methodMirror
case(is JavaBeanValue) annotated.mirror
case(is JavaMethod) annotated.mirror
else null;

shared Declaration? parseAnnotationType(String encodedDeclaration, ModuleManager? moduleManager) {
    String withoutVersion;
    if (!exists moduleManager) {
        return null;
    }
    if (exists first=encodedDeclaration.first,
        first == ':') {
        // a version exist
        value rest = encodedDeclaration.rest;
        value sentinel = rest.first;
        if (!exists sentinel) {
            return null;
        }
        value versionEnd = rest.rest.firstOccurrence(sentinel);
        if (!exists versionEnd) {
            return null;
        }
        withoutVersion = rest.rest.spanFrom(versionEnd+1);
    } else {
        withoutVersion = encodedDeclaration;
    }
    
    value fromModule = withoutVersion.split(':'.equals, true, false);
    value moduleName = fromModule.first;
    Module? mod = moduleManager.findLoadedModule(moduleName, null);
    if (!exists mod) {
        return null;
    }
    
    value fromPackage = fromModule.rest;
    value packageName = fromPackage.first;
    if (!exists packageName) {
        return null;
    }
    Package? pkg = mod.getPackage(
        if (exists nameStart = packageName.first,
            nameStart == '.')
        then packageName.rest
        else 
        if (packageName.empty) 
        then moduleName
        else "``moduleName``.``packageName``");
    if (!exists pkg) {
        return null;
    }
    
    value fromDeclaration = fromPackage.rest;
    value declaration = fromDeclaration.first;
    if (!exists declaration) {
        return null;
    }
    if (!fromDeclaration.rest.empty) {
        return null; // the syntax cannot be parsed
    }
    value declarationParts = declaration.split('.'.equals)
            .map((s) => s.rest);
    Declaration? topLeveldeclaration = pkg.getMember(declarationParts.first, null, false);
    
    function toRealParent(Declaration? parent) =>
            switch(parent)
    case (is Null) null
    case (is LazyValue) 
    let (TypeDeclaration? typeDeclaration = parent.typeDeclaration) 
    if (equalsWithNulls(typeDeclaration?.qualifiedNameString, parent.qualifiedNameString))
    then typeDeclaration else parent
    else parent;
    
    return declarationParts.rest
            .fold(topLeveldeclaration)
    ((Declaration? parent, String member) => 
        toRealParent(parent)?.getMember(member, null, false));
}


