import ceylon.collection {
    MutableSet,
    HashSet
}

import com.redhat.ceylon.ide.common.model {
    IdeModuleManager,
    IdeModuleSourceMapper,
    BaseCeylonProject,
    BaseIdeModelLoader,
    BaseIdeModuleManager,
    BaseIdeModuleSourceMapper,
    BaseIdeModule,
    IdeModule
}
import com.redhat.ceylon.model.cmr {
    JDKUtils
}
import com.redhat.ceylon.model.loader {
    AbstractModelLoader
}
import com.redhat.ceylon.model.typechecker.model {
    Modules
}

import java.io {
    File
}

shared class DummyModuleManager(DummyCeylonProject ceylonProject)
        extends IdeModuleManager<DummyProject, File, File, File>(ceylonProject.model, ceylonProject) {
    
    shared actual Boolean moduleFileInProject(String moduleName, BaseCeylonProject? ceylonProject) => false;
    
    shared actual BaseIdeModelLoader newModelLoader(BaseIdeModuleManager self, BaseIdeModuleSourceMapper sourceMapper, Modules modules) {
        assert (is DummyModuleSourceMapper sourceMapper);
        assert (is DummyModuleManager self);
        value modelLoader = DummyModelLoader(self, sourceMapper, modules);
        return modelLoader;
    }
    
    shared actual BaseIdeModule newModule(String moduleName, String version) => object extends IdeModule<DummyProject, File, File, File>() {

        shared actual Set<String> listPackages() {
            MutableSet<String> packageList = HashSet<String>();
            value name = nameAsString;
            if (JDKUtils.isJDKModule(name)) {
                packageList.addAll { for (p in JDKUtils.getJDKPackagesByModule(name)) p.string };
            }
            else if (JDKUtils.isOracleJDKModule(name)) {
                packageList.addAll { for (p in JDKUtils.getOracleJDKPackagesByModule(name)) p.string };
            }
            else if (java || true) {  // TODO : check this - the `|| true` part is strange
                if (isJavaBinaryArchive || isCeylonBinaryArchive) {
                    assert(is DummyModelLoader dml = modelLoader);
                    for (pkg in dml.classLoader.packages) {
                        if (moduleName in pkg.name) {
                            packageList.add(pkg.name);
                        }
                    }
                }
            }
            return packageList;
        }
        shared actual AbstractModelLoader modelLoader => outer.modelLoader;
        shared actual IdeModuleManager<DummyProject,File,File,File> moduleManager => outer;
        shared actual IdeModuleSourceMapper<DummyProject,File,File,File> moduleSourceMapper {
            assert(is DummyModuleSourceMapper msm = outer.moduleSourceMapper);
            return msm;
        }
        shared actual void refreshJavaModel() {
        }
    };
}


