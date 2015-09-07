import com.redhat.ceylon.cmr.api {
    ModuleQuery,
    ModuleVersionQuery
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject
}

shared object moduleQueries {
    
    shared ModuleQuery getModuleQuery<IdeArtifact>(String prefix, CeylonProject<IdeArtifact>? project) {
        if (exists project) {
            Boolean compileToJava = true; // TODO take from project
            Boolean compileToJs = false; // TODO take from project
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
    
    shared ModuleVersionQuery getModuleVersionQuery<IdeArtifact>(String name, String version, CeylonProject<IdeArtifact>? project) {
        if (exists project) {
            Boolean compileToJava = true; // TODO take from project
            Boolean compileToJs = false; // TODO take from project
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
