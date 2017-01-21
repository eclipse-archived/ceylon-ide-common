import ceylon.interop.java {
    javaString,
    CeylonIterable
}
import ceylon.language.meta.declaration {
    FunctionOrValueDeclaration,
    FunctionDeclaration,
    ClassDeclaration
}
import ceylon.test {
    test,
    testExecutor
}
import ceylon.test.engine {
    DefaultTestExecutor
}
import ceylon.test.engine.spi {
    ArgumentProviderContext,
    ArgumentProvider,
    TestExecutionContext
}

import com.redhat.ceylon.compiler.java.codegen {
    Decl,
    ClassTransformer
}
import com.redhat.ceylon.compiler.typechecker {
    TypeCheckerBuilder
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    AnalysisError
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit,
    PhasedUnits
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject,
    BaseIdeModule
}
import com.redhat.ceylon.model.cmr {
    ArtifactResult,
    Exclusion,
    PathFilter,
    ModuleScope,
    Repository,
    ArtifactResultType,
    VisibilityType
}
import com.redhat.ceylon.model.loader {
    ModelLoader {
        DeclarationType
    }
}
import com.redhat.ceylon.model.loader.model {
    LazyElement,
    LazyClass,
    LazyClassAlias,
    LazyInterface,
    LazyInterfaceAlias,
    LazyValue,
    LazyTypeAlias,
    LazyFunction
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    ClassOrInterface,
    Setter,
    Function
}

import java.io {
    File
}
import java.lang {
    ProcessBuilder
}
import java.util {
    Map,
    HashMap,
    Arrays,
    List,
    Collections
}

import test.com.redhat.ceylon.ide.common.platform {
    testPlatform
}
import test.com.redhat.ceylon.ide.common.util {
    dummyProgressMonitor
}
import com.redhat.ceylon.compiler.java.loader {
    CeylonEnter
}


String getQualifiedPrefixedName(Declaration decl){
    String name = Decl.className(decl);
    Nothing noPrefix() {
        throw AssertionError("Don't know how to prefix decl: ``decl``");          
    }
    suppressWarnings("expressionTypeNothing")
    String prefix =
    if(is ClassOrInterface decl)
    then "C"
    else if(Decl.isValue(decl))
    then "V"
    else if(Decl.isGetter(decl))
    then "G"
    else if(decl is Setter)
    then "S"
    else if(is Function decl)
    then "M"
    else noPrefix();
    
    return prefix + name;
}

shared annotation PhasedUnitsAnnotation phasedUnits() => PhasedUnitsAnnotation();

shared final annotation class PhasedUnitsAnnotation()
        satisfies OptionalAnnotation<PhasedUnitsAnnotation,FunctionOrValueDeclaration> & ArgumentProvider {
    
    shared actual {Anything*} arguments(ArgumentProviderContext context) => {
        for (pu in testModelBasedMirrors.phasedUnits.phasedUnits)
            if (pu.unitFile.name != "module.ceylon" &&
                pu.unitFile.name != "package.ceylon" )
            pu
    };
}

shared class CleaningTestExecutor(FunctionDeclaration functionDeclaration, ClassDeclaration? classDeclaration) 
        extends DefaultTestExecutor(functionDeclaration, classDeclaration) {
    shared actual void execute(TestExecutionContext context) {
        testPlatform.register();
        testModelBasedMirrors.beforeTests();
        try {
            super.execute(context);
        } finally {
            testModelBasedMirrors.afterTests();
        }
    }
}

shared object testModelBasedMirrors {
    variable File? dir = File("").absoluteFile;
    variable File? ceylonDir = null;
    variable File? modelLoaderTestsSrcDir = null;
    variable File? modelLoaderTestsDir = null;
    variable File? distRepoDir = null;
    
    shared variable CeylonProject<DummyProject, File, File, File>? ceylonProjectBuildSources = null;
    shared variable CeylonProject<DummyProject, File, File, File>? ceylonProjectFromBinaries = null;
    shared variable CeylonProject<DummyProject, File, File, File>? ceylonProjectFromSources = null;
    shared variable late PhasedUnits phasedUnits;
    
    shared void beforeTests() {
        while (exists existingDir = dir) {
            value triedCeylonDir = File(existingDir,"ceylon");
            if (triedCeylonDir.\iexists()) {
                ceylonDir = triedCeylonDir;
                value triedModelLoaderTestsSrcDir = File(File(File(ceylonDir, "compiler-java"), "test"), "src");
                if (triedModelLoaderTestsSrcDir.\iexists()) {
                    modelLoaderTestsSrcDir = triedModelLoaderTestsSrcDir;
                    value triedModelLoaderTestsDir = File(File(File(File(File(File(File(modelLoaderTestsSrcDir, "com"), "redhat"), "ceylon"), "compiler"), "java"), "test"), "model");
                    if (triedModelLoaderTestsDir.\iexists()) {
                        modelLoaderTestsDir = triedModelLoaderTestsDir;
                    }
                    
                }
                value triedCeylonDistRepoDir = File(File(File(ceylonDir, "dist"), "dist"), "repo");
                if (triedCeylonDistRepoDir.\iexists()) {
                    distRepoDir = triedCeylonDistRepoDir;
                }
                if (modelLoaderTestsDir exists && distRepoDir exists) {
                    break;
                }
            }
            dir = dir?.parentFile;
        }
        
        "The model loader tests directory is not found"
        assert (exists ceylonRootDir = ceylonDir);
        "The model loader tests directory is not found"
        assert (exists modelLoaderTestsDirectory = modelLoaderTestsDir);
        "The model loader tests root directory is not found"
        assert (exists modelLoaderTestsSrcDirectory = modelLoaderTestsSrcDir);
        "The ceylon dist repository is not found"
        assert (exists repoDir = distRepoDir);
        
        value typeChecker = TypeCheckerBuilder()
                .statistics(true)
                .verbose(false)
                .setModuleFilters(Arrays.asList(javaString("com.redhat.ceylon.compiler.java.test.model")))
                .addSrcDirectory(modelLoaderTestsSrcDirectory)
                .typeChecker;
        
        phasedUnits = typeChecker.phasedUnits;
        
        value phasedUnitsToSkip = [
            for (pu in phasedUnits.phasedUnits)
                if (! pu.unitFile.name.endsWith(".ceylon") ||
                    pu.unitFile.name.startsWith("Bug") ||
                    pu.unitFile.name.endsWith("test.ceylon") ||
                    pu.unitFile.name.startsWith("bogus") ||
                    pu.unitFile.name.startsWith("Java")) 
                pu
        ];
        
        for (pu in phasedUnitsToSkip) {
            phasedUnits.removePhasedUnitForRelativePath(pu.pathRelativeToSrcDir);
        }
        
        typeChecker.process();
        
        value outputForBinaries = "modelLoaderTestsBinaries";
        value sourceModules = set { 
            for (pu in phasedUnits.phasedUnits) pu.unit.\ipackage
        }.group((pkg) => pkg.\imodule);
        
        value processBuilder = ProcessBuilder(Arrays.asList(*{
            File(File(repoDir.parentFile, "bin"), 
                "ceylon`` operatingSystem.name == "windows" then ".bat" else "" ``")
                    .absolutePath,
            "compile",
            "--suppress-warning",
            "--source=``modelLoaderTestsSrcDirectory.absolutePath``",
            "--out=`` outputForBinaries ``",
            for (pu in phasedUnits.phasedUnits) pu.unitFile.path
        }.map(javaString)));
        processBuilder.inheritIO();
        print(processBuilder.command());
        processBuilder.start().waitFor();
        
        testPlatform.installModelServices(modelServices);
        testPlatform.installVfsServices(vfsServices);

        dummyModel.addProject(DummyProject(File(""), repoDir, false, "toBuildSources"));
        dummyModel.addProject(DummyProject(File(""), repoDir, true, "mirrorsLoadedFromBinaries"));
        dummyModel.addProject(DummyProject(File(""), repoDir, false, "mirrorsLoadedFromSources"));
        ceylonProjectBuildSources = dummyModel.ceylonProjects.first;
        ceylonProjectFromBinaries = dummyModel.ceylonProjects.rest.first;
        ceylonProjectFromSources = dummyModel.ceylonProjects.rest.rest.first;
        
        for (ceylonProject in dummyModel.ceylonProjects) {
            ceylonProject.parseCeylonModel(dummyProgressMonitor);
            ceylonProject.build.consumeModelChanges(dummyProgressMonitor);
            ceylonProject.build.updateCeylonModel(dummyProgressMonitor);
            
            assert(exists modules = ceylonProject.modules);
            assert(is DummyModelLoader modelLoader = ceylonProject.modelLoader);
            assert(is DummyModuleSourceMapper moduleSourceMapper = modules.sourceMapper);
            for (sourceModule->packages in sourceModules) {
                value theModule = modelLoader.findOrCreateModule(sourceModule.nameAsString, sourceModule.version);
                for (pkg in packages) {
                    modelLoader.findOrCreatePackage(theModule, pkg.nameAsString);
                }
                if (ceylonProject.ideArtifact.name == "mirrorsLoadedFromSources") {
                    modelLoader.addModuleToClassPath(theModule, null);
                }
                if (ceylonProject.ideArtifact.name == "mirrorsLoadedFromBinaries") {
                    variable File moduleArchive = File(outputForBinaries);
                    for (part in theModule.name) {
                        moduleArchive = File(moduleArchive, part.string);
                    }
                    moduleArchive = File(moduleArchive, theModule.version);
                    moduleArchive = File(moduleArchive, "`` theModule.nameAsString ``-`` theModule.version ``.car");
                    
                    assert(is BaseIdeModule theModule);
                    object  artifact satisfies ArtifactResult {
                        shared actual File artifact() => moduleArchive;
                        shared actual List<ArtifactResult> dependencies() => Collections.emptyList<ArtifactResult>();
                        shared actual List<Exclusion> exclusions => Collections.emptyList<Exclusion>();
                        shared actual Boolean exported() => true;
                        shared actual PathFilter? filter() => null;
                        shared actual ModuleScope? moduleScope() => null;
                        shared actual String name() => theModule.nameAsString;
                        shared actual String? namespace() => null;
                        shared actual Boolean optional() => false;
                        shared actual Repository? repository() => null;
                        shared actual String repositoryDisplayString() => "dummy";
                        shared actual ArtifactResultType type() => ArtifactResultType.ceylon;
                        shared actual String version() => theModule.version;
                        shared actual VisibilityType visibilityType() => VisibilityType.strict;
                    }
                    
                    theModule.setArtifactResult(artifact);
                    
                    "The binary module archive is not found"
                    assert(moduleArchive.\iexists());
                    modelLoader.addModuleToClassPath(theModule, artifact);
                }
            }
            if (ceylonProject.ideArtifact.name == "mirrorsLoadedFromSources") {
                modelLoader.addTestedPhasedUnits(phasedUnits.phasedUnits);
            }            
            if (ceylonProject.ideArtifact.name == "toBuildSources") {
                assert(exists pus = ceylonProject.typechecker?.phasedUnits);
                for (pu in phasedUnits.phasedUnits) {
                    value mod = modelLoader.findOrCreateModule(pu.unit.\ipackage.\imodule.nameAsString, pu.unit.\ipackage.\imodule.version);
                    value pkg = modelLoader.findOrCreatePackage(mod, pu.unit.\ipackage.nameAsString);
                    moduleSourceMapper.currentPackage_ = pkg;
                    pus.parseUnit(pu.unitFile, pu.srcDir);
                }
                pus.visitModules();
                value listOfUnits = pus.phasedUnits;
                for (pu in listOfUnits) {
                    pu.validateTree();
                    pu.scanDeclarations();
                }
                for (pu in listOfUnits) {
                    pu.scanTypeDeclarations();
                }
                for (pu in listOfUnits) {
                    pu.validateRefinement();
                }
                for (pu in listOfUnits) {
                    pu.analyseTypes();
                }
                for (pu in listOfUnits) {
                    pu.analyseFlow();
                }
                for (pu in listOfUnits) {
                    pu.analyseUsage();
                }
                
                assert(exists javacContext = ceylonProject.createJavacContextWithClassTransformer());
                CeylonEnter.additionalTypecheckingPhases(listOfUnits, null, modelLoader, ClassTransformer.getInstance(javacContext).gen());
                
                phasedUnits = pus;
            }
        }
    }
    
    shared void afterTests() {
        if (exists projectToBuildSources = ceylonProjectBuildSources?.ideArtifact) {
            dummyModel.removeProject(projectToBuildSources);
        }
        ceylonProjectBuildSources = null;
        if (exists projectFromBinaries = ceylonProjectFromBinaries?.ideArtifact) {
            dummyModel.removeProject(projectFromBinaries);
        }
        ceylonProjectFromBinaries = null;
        if (exists projectFromSources = ceylonProjectFromSources?.ideArtifact) {
            dummyModel.removeProject(projectFromSources);
        }
        ceylonProjectFromSources = null;
    }

    testExecutor(`class CleaningTestExecutor`)
    test
    shared void testModel(phasedUnits PhasedUnit pu) {
        Map<String,Declaration> decls = HashMap<String,Declaration>();
        
        assert(is DummyCeylonProject ceylonProjectFromBinaries = this.ceylonProjectFromBinaries);
        assert(is DummyCeylonProject ceylonProjectFromSources = this.ceylonProjectFromSources);
        assert(CeylonIterable(pu.compilationUnit.errors).narrow<AnalysisError>().empty);
        
        for(decl in pu.unit.declarations){
            if(decl.toplevel){
                decls.put(getQualifiedPrefixedName(decl), decl);
            }
        }
        
        function getMirror(LazyElement d) =>
                switch(d)
                case(is LazyValue) d.classMirror
                case(is LazyFunction) d.classMirror
                case(is LazyClass) d.classMirror
                case(is LazyClassAlias) d.classMirror
                case(is LazyInterface) d.classMirror
                case(is LazyInterfaceAlias) d.classMirror
                case(is LazyTypeAlias) d.classMirror
                else null;
        
        for(decl in decls.values()){
            assert(exists sourcesModelLoader = ceylonProjectFromSources.modelLoader);
            assert(exists binariesModelLoader = ceylonProjectFromBinaries.modelLoader);
            String quotedQualifiedName = sourcesModelLoader.getToplevelQualifiedName(decl.qualifiedNameString.replace("::", "."));
            value moduleFromSources = sourcesModelLoader.findOrCreateModule(pu.\ipackage.\imodule.nameAsString, pu.\ipackage.\imodule.version);
            Declaration? modelDeclarationFromSources = sourcesModelLoader.getDeclaration(moduleFromSources, quotedQualifiedName, 
                if(Decl.isValue(decl)) then DeclarationType.\ivalue else DeclarationType.type);
            
            value moduleFromBinaries = binariesModelLoader.findOrCreateModule(pu.\ipackage.\imodule.nameAsString, pu.\ipackage.\imodule.version);
            Declaration? modelDeclarationFromBinaries = binariesModelLoader.getDeclaration(moduleFromBinaries, quotedQualifiedName, 
                if(Decl.isValue(decl)) then DeclarationType.\ivalue else DeclarationType.type);
/*
            // make sure we loaded them exactly the same
            try {
                ModelComparison().compareDeclarations(decl.qualifiedNameString, decl, modelDeclarationFromBinaries);
            } catch(AssertionError e) {
                throw Exception("Model loaded from binaries is invalid, and cannot be used as reference for source-based mirrors:", e);
            }
            try {
                ModelComparison().compareDeclarations(decl.qualifiedNameString, decl, modelDeclarationFromSources);
            } catch(AssertionError e) {
                if (is LazyElement modelDeclarationFromBinaries,
                    is LazyElement modelDeclarationFromSources) {
                    MirrorComparison().compareAnyMirror(getMirror(modelDeclarationFromBinaries), getMirror(modelDeclarationFromSources));
                }
                throw e;
            }
*/
            assert(is LazyElement modelDeclarationFromBinaries, 
                    is LazyElement modelDeclarationFromSources);
            MirrorComparison().compareAnyMirror(getMirror(modelDeclarationFromBinaries), getMirror(modelDeclarationFromSources));
        }
    }    
}
