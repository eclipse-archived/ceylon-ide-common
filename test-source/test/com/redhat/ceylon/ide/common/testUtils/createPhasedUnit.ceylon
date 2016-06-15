import ceylon.collection {
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable,
    javaString,
    JavaList
}

import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils {
        repoManager
    }
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker {
        languageModuleVersion=\iLANGUAGE_MODULE_VERSION
    }
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleValidator
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit,
    PhasedUnits,
    Context
}
import com.redhat.ceylon.compiler.typechecker.io {
    VFS,
    VirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    Unit
}
import com.redhat.ceylon.ide.common.model.delta {
    ...
}

import java.io {
    InputStream,
    ByteArrayInputStream
}
import java.util {
    JList=List,
    Collections {
        emptyList
    }
}
import com.redhat.ceylon.ide.common.model {
    cancelDidYouMeanSearch
}

shared class SourceCode(contents, path) {
    shared String contents;
    shared String path;
}

shared Map<String, PhasedUnit?> parseAndTypecheckCode({SourceCode*} codeCollection, Boolean jdkIncluded = false) {
    value repositoryManager = repoManager()
                .offline(true)
//                .cwd(cwd)
//                .systemRepo(systemRepo)
//                .extraUserRepos(getReferencedProjectsOutputRepositories(project))
//                .logger(new EclipseLogger())
                .isJDKIncluded(jdkIncluded)
                .buildManager();

    value context = Context(repositoryManager, VFS());
    value phasedUnits = PhasedUnits(context);

    abstract class TestVirtualFile(path) satisfies VirtualFile {
        suppressWarnings("expressionTypeNothing")
        shared default actual InputStream inputStream => nothing;
        shared actual String name => path.split('/'.equals, true, true).last;
        shared actual String path;
        suppressWarnings("expressionTypeNothing")
        shared actual Integer compareTo(VirtualFile? t) => nothing;
    }

    class TestFile(String path, String contents) extends TestVirtualFile(path) {
        shared actual JList<VirtualFile> children => emptyList<VirtualFile>();
        shared actual Boolean \iexists() => true;
        shared actual Boolean folder => false;
        shared actual InputStream inputStream => ByteArrayInputStream(javaString(contents + " ").bytes);
    }

    class TestDirectory(String path) extends TestVirtualFile(path) {
        shared actual Boolean \iexists() => true;
        shared actual Boolean folder => true;
        value theChildren = ArrayList<TestVirtualFile>();

        shared TestFile createFile(String filePath, String contents) {
            return createChild(filePath.split('/'.equals).sequence(), contents);
        }

        shared actual JList<VirtualFile> children => JavaList<VirtualFile>(theChildren.collect<VirtualFile>((TestVirtualFile element) => element));

        TestFile createChild([String*] filePath, String contents) {
            if (nonempty filePath, nonempty rest = filePath.rest) {
                value subFolder =  TestDirectory ("/".join { path, filePath.first });
                theChildren.add(subFolder);
                return subFolder.createChild(rest, contents);

            } else {
                value file = TestFile("/".join { path, *filePath }, contents);
                theChildren.add(file);
                return file;
            }
        }
    }


    value srcDir = TestDirectory("");
    for (code in codeCollection) {
        srcDir.createFile(code.path, code.contents);
    }

    phasedUnits.parseUnit(srcDir);

    phasedUnits.moduleManager.prepareForTypeChecking();
    phasedUnits.visitModules();
    phasedUnits.moduleManager.modulesVisited();

    value defaultUnit = Unit();
    context.modules.defaultModule.unit = defaultUnit;
    context.modules.defaultModule.packages.get(0).unit = defaultUnit;
    defaultUnit.\ipackage = context.modules.defaultModule.packages.get(0);
    
    //By now the language module version should be known (as local)
    //or we should use the default one.
    Module languageModule = context.modules.languageModule;
    String? version = languageModule.version;
    if (version is Null) {
        languageModule.version = languageModuleVersion;
    }

    value moduleValidator = ModuleValidator(context, phasedUnits);
    moduleValidator.verifyModuleDependencyTree();

    value listOfUnits = CeylonIterable(phasedUnits.phasedUnits);

    for (pu in listOfUnits) {
        pu.validateTree();
        pu.scanDeclarations();
    }
    for (pu in listOfUnits) {
        pu.scanTypeDeclarations(cancelDidYouMeanSearch);
    }
    for (pu in listOfUnits) {
        pu.validateRefinement();
    }
    for (pu in listOfUnits) {
        pu.analyseTypes(cancelDidYouMeanSearch);
    }
    for (pu in listOfUnits) {
        pu.analyseFlow();
    }
    for (pu in listOfUnits) {
        pu.analyseUsage();
    }

    return object satisfies Map<String, PhasedUnit?> {
        suppressWarnings("expressionTypeNothing")
        shared actual Map<String,PhasedUnit?> clone() => nothing;

        shared actual Boolean defines(Object key)
                => codeCollection.any((SourceCode code) => code.path == key);

        shared actual PhasedUnit? get(Object key)
                => if (is String key)
                    then phasedUnits.getPhasedUnitFromRelativePath(key)
                    else null;

        shared actual Iterator<String->PhasedUnit?> iterator()
                => codeCollection.map(
                    (SourceCode code)
                            => code.path->phasedUnits.getPhasedUnitFromRelativePath(code.path))
                    .iterator();

        shared actual Integer hash => (super of Map<String, PhasedUnit?>).hash;
        shared actual Boolean equals(Object that) => (super of Map<String, PhasedUnit?>).equals(that);
    };
}
