/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.cmr.api {
    ModuleQuery,
    ModuleVersionQuery
}
import org.eclipse.ceylon.ide.common.model {
    BaseCeylonProject
}
import org.eclipse.ceylon.model.typechecker.model {
    Module
}
import org.eclipse.ceylon.common {
    Backend
}

shared object moduleQueries {
    
    shared ModuleQuery getModuleQuery(String prefix, Module? mod, BaseCeylonProject? project,
        String? namespace = null) {
        if (exists mod) {
            if (exists backends = mod.nativeBackends) {
                value compileToJava = backends.supports(Backend.java);
                value compileToJs = backends.supports(Backend.javaScript);
                if (compileToJava, !compileToJs) {
                    return ModuleQuery(namespace, prefix, ModuleQuery.Type.jvm);
                }
                
                if (compileToJs, !compileToJava) {
                    return ModuleQuery(namespace, prefix, ModuleQuery.Type.js);
                }
            }
        }
        
        return getModuleQuery2(prefix, project, namespace);
    }

    shared ModuleQuery getModuleQuery2(String prefix, BaseCeylonProject? project,
        String? namespace = null) {
        if (exists project) {
            Boolean compileToJava = project.ideConfiguration.compileToJvm else false;
            Boolean compileToJs = project.ideConfiguration.compileToJs else false;
            if (compileToJava, !compileToJs) {
                return ModuleQuery(namespace, prefix, ModuleQuery.Type.jvm);
            }
            if (compileToJs, !compileToJava) {
                return ModuleQuery(namespace, prefix, ModuleQuery.Type.js);
            }
            if (compileToJs, compileToJava) {
                return ModuleQuery(namespace, prefix, ModuleQuery.Type.ceylonCode, ModuleQuery.Retrieval.all);
            }
        }
        return ModuleQuery(namespace, prefix, ModuleQuery.Type.code);
    }
    
    shared ModuleVersionQuery getModuleVersionQuery(String name, String version, BaseCeylonProject? project) {
        if (exists project) {
            Boolean compileToJava = project.ideConfiguration.compileToJvm else false;
            Boolean compileToJs = project.ideConfiguration.compileToJs else false;
            if (compileToJava, !compileToJs) {
                return ModuleVersionQuery(name, version, ModuleQuery.Type.jvm);
            }
            if (compileToJs, !compileToJava) {
                return ModuleVersionQuery(name, version, ModuleQuery.Type.js);
            }
            if (compileToJs, compileToJava) {
                ModuleVersionQuery mvq = ModuleVersionQuery(name, version, ModuleQuery.Type.ceylonCode);
                mvq.retrieval = ModuleQuery.Retrieval.all;
            }
        }
        return ModuleVersionQuery(name, version, ModuleQuery.Type.code);
    }

}
