import ceylon.collection {
    naturalOrderTreeMap,
    naturalOrderTreeSet
}
import ceylon.interop.java {
    createJavaObjectArray,
    javaClass
}

import com.redhat.ceylon.cmr.api {
    ArtifactContext
}
import com.redhat.ceylon.common {
    Versions
}
import com.redhat.ceylon.compiler.java.loader {
    SourceDeclarationVisitor
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    IdeModelLoader,
    BaseIdeModule,
    IdeModuleManager,
    IdeModuleSourceMapper
}
import com.redhat.ceylon.ide.common.model.asjava {
    JMethodMirror,
    CeylonToJavaMapper
}
import com.redhat.ceylon.ide.common.model.mirror {
    SourceDeclarationHolder
}
import com.redhat.ceylon.model.cmr {
    ArtifactResult
}
import com.redhat.ceylon.model.loader.impl.reflect.mirror {
    ReflectionClass,
    ReflectionMethod
}
import com.redhat.ceylon.model.loader.mirror {
    ClassMirror,
    MethodMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Modules,
    Module,
    Declaration
}

import java.io {
    File
}
import java.lang {
    ClassNotFoundException,
    Class
}
import java.net {
    URLClassLoader,
    URL
}
import java.util {
    JList=List
}


shared class DummyModelLoader(
    IdeModuleManager<DummyProject, File, File, File> moduleManager,
    IdeModuleSourceMapper<DummyProject, File, File, File> moduleSourceMapper,
    Modules modules
) extends IdeModelLoader<DummyProject, File, File, File, Nothing, Nothing>(
    moduleManager,
    moduleSourceMapper,
    modules){

    value _testedPackages = naturalOrderTreeSet<String> {};
    value _testedDeclarations = naturalOrderTreeMap<String, SourceDeclarationHolder> {};
    shared class ArtifactClassLoader() extends URLClassLoader(createJavaObjectArray<URL>{}, javaClass<DummyModelLoader>().classLoader) {
        shared void addArtifact(ArtifactResult artifact) => super.addURL(artifact.artifact().toURI().toURL());
        shared actual Class<out Object> loadClass(String? name) => super.loadClass(name, true);
        packages => super.packages;
    }
    
    shared ArtifactClassLoader classLoader = ArtifactClassLoader();
    assert(exists ceylonProject = moduleManager.ceylonProject);
    value repoManager = ceylonProject.repositoryManager;
    
    for (basicModule in {
        "ceylon.language", 
        "com.redhat.ceylon.common", 
        "com.redhat.ceylon.model", 
        "com.redhat.ceylon.langtools.classfile",
        "com.redhat.ceylon.module-resolver" }) {
        if (exists result = repoManager.getArtifactResult(ArtifactContext(null, basicModule, Versions.ceylonVersionNumber))) {
            classLoader.addArtifact(result);
        }
    }
    variable CeylonToJavaMapper? ceylonToJavaMapper_ = null;
    
    shared actual class PackageLoader(BaseIdeModule ideModule)
             extends super.PackageLoader(ideModule) {
        packageExists(String quotedPackageName) => false;
        packageMembers(String quotedPackageName) => {};
        shouldBeOmitted(Nothing type) => true;
    }
    
    moduleContainsClass(BaseIdeModule ideModule, String packageName, String className) => false;
    typeExists(Nothing type) => false;
    typeName(Nothing type) => "";

    value ceylonToJavaMapper => ceylonToJavaMapper_
            else (ceylonToJavaMapper_ = CeylonToJavaMapper {
                ceylonProject = ceylonProject;
                function toSource(Declaration d) {
                    value path = d.unit?.fullPath;
                    return testModelBasedMirrors.phasedUnits.getPhasedUnit(path);
                }
            });
    
    shared actual void addModuleToClasspathInternal(ArtifactResult? artifact) {
        if (exists artifact) {
            classLoader.addArtifact(artifact);
        }
    }

    shared actual Boolean isOverloadingMethod(MethodMirror? methodMirror) {
        switch (methodMirror)
        case (is ReflectionMethod) {
            return methodMirror.overloadingMethod;
        }
        case(is JMethodMirror) {
            return false;
        }
        else {
            return false;
        }
    }
    
    shared actual Boolean isOverridingMethod(MethodMirror? methodMirror) {
        switch (methodMirror)
        case (is ReflectionMethod) {
            value method = methodMirror.method;
            if (method.declaringClass.name == "ceylon.language.Identifiable") {
                if (method.name == "equals" || method.name == "hashCode") {
                    return true;
                }
            }
            if (method.declaringClass.name == "ceylon.language.Object") {
                if (method.name == "equals" || method.name == "hashCode" || method.name == "toString") {
                    return false;
                }
            }
            return methodMirror.overridingMethod;
            
        }
        case(is JMethodMirror) {
            return false;
        }
        else {
            return false;
        }
    }

    shared void addTestedPhasedUnits(JList<PhasedUnit> treeHolders)
            => runWithLock(() {
        for (treeHolder in treeHolders) {
            value pkgName = treeHolder.\ipackage.qualifiedNameString;
            _testedPackages.add(pkgName);
            treeHolder.compilationUnit.visit(object extends SourceDeclarationVisitor(){
                shared actual void loadFromSource(Tree.Declaration decl) {
                    if (exists id=decl.identifier) {
                        String fqn = getToplevelQualifiedName(pkgName + "." + id.text);
                        if (! _testedDeclarations.defines(fqn)) {
                            _testedDeclarations[fqn]
                                    = SourceDeclarationHolder(treeHolder, decl, true);
                        }
                    }
                }
                shared actual void loadFromSource(Tree.ModuleDescriptor that) {}
                shared actual void loadFromSource(Tree.PackageDescriptor that) {}
            });
        }
    });

    shared SourceDeclarationHolder? lookupTestedDeclaration(String name) {
        String topLevelPartiallyQuotedName = getToplevelQualifiedName(name);
        return _testedDeclarations.get(topLevelPartiallyQuotedName);
    }
    
    shared actual ClassMirror? buildClassMirrorInternal(String string) {
        if (exists testedDeclaration = lookupTestedDeclaration(string)?.modelDeclaration,
            is ClassMirror mirror = ceylonToJavaMapper.mapDeclaration(testedDeclaration)[0]) {
            return mirror;
        }
        if (! _testedPackages.any((pkg) => "``pkg``." in string)) {
            try {
                return ReflectionClass(classLoader.loadClass(string));
            } catch(ClassNotFoundException e) {}
        }
        
        return null;
    }
    
    shared actual Module findOrCreateModule(String? theModuleName, String? theVersion) =>
            super.findOrCreateModule(theModuleName, theVersion);
    
    getToplevelQualifiedName(String str) => super.getToplevelQualifiedName(str);
}