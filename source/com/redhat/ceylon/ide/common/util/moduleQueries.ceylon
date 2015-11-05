import com.redhat.ceylon.cmr.api {
    ModuleQuery,
    ModuleVersionQuery
}
import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}
import com.redhat.ceylon.common {
    Backend
}

shared object moduleQueries {
    
    shared ModuleQuery getModuleQuery(String prefix, Module? mod, BaseCeylonProject? project) {
        if (exists mod) {
            if (exists backends = mod.nativeBackends) {
                value compileToJava = backends.supports(Backend.\iJava);
                value compileToJs = backends.supports(Backend.\iJavaScript);
                if (compileToJava, !compileToJs) {
                    return ModuleQuery(prefix, ModuleQuery.Type.\iJVM);
                }
                
                if (compileToJs, !compileToJava) {
                    return ModuleQuery(prefix, ModuleQuery.Type.\iJS);
                }
            }
        }
        
        return getModuleQuery2(prefix, project);
    }

    shared ModuleQuery getModuleQuery2(String prefix, BaseCeylonProject? project) {
        if (exists project) {
            Boolean compileToJava = project.ideConfiguration.compileToJvm else false;
            Boolean compileToJs = project.ideConfiguration.compileToJs else false;
            if (compileToJava, !compileToJs) {
                return ModuleQuery(prefix, ModuleQuery.Type.\iJVM);
            }
            if (compileToJs, !compileToJava) {
                return ModuleQuery(prefix, ModuleQuery.Type.\iJS);
            }
            if (compileToJs, compileToJava) {
                return ModuleQuery(prefix, ModuleQuery.Type.\iCEYLON_CODE, ModuleQuery.Retrieval.\iALL);
            }
        }
        return ModuleQuery(prefix, ModuleQuery.Type.\iCODE);
    }
    
    shared ModuleVersionQuery getModuleVersionQuery(String name, String version, BaseCeylonProject? project) {
        if (exists project) {
            Boolean compileToJava = project.ideConfiguration.compileToJvm else false;
            Boolean compileToJs = project.ideConfiguration.compileToJs else false;
            if (compileToJava, !compileToJs) {
                return ModuleVersionQuery(name, version, ModuleQuery.Type.\iJVM);
            }
            if (compileToJs, !compileToJava) {
                return ModuleVersionQuery(name, version, ModuleQuery.Type.\iJS);
            }
            if (compileToJs, compileToJava) {
                ModuleVersionQuery mvq = ModuleVersionQuery(name, version, ModuleQuery.Type.\iCEYLON_CODE);
                mvq.retrieval = ModuleQuery.Retrieval.\iALL;
            }
        }
        return ModuleVersionQuery(name, version, ModuleQuery.Type.\iCODE);
    }

}
