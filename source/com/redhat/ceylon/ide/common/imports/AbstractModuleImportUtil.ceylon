import ceylon.interop.java {
    CeylonIterable,
    javaString
}

import com.redhat.ceylon.common {
    Backends
}
import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.correct {
    DocumentChanges
}
import com.redhat.ceylon.ide.common.modulesearch {
    ModuleVersionNode,
    ModuleNode
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    Indents
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}

import java.lang {
    //StringBuilder,
    ObjectArray,
    JString=String
}
import java.util {
    Collections
}

shared abstract class AbstractModuleImportUtil<IFile,IProject,IDocument,InsertEdit,TextEdit,TextChange>()
        satisfies DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit {
    
    shared formal TextChange newTextChange(String desc, IFile file);
    
    shared formal void performChange(TextChange change);
    
    shared formal Indents<IDocument> indents;
    
    shared formal [IFile, Tree.CompilationUnit, TypecheckerUnit] getUnit(IProject project, Module mod);
    
    shared formal Character getChar(IDocument doc, Integer offset);
    
    shared formal Integer getEditOffset(TextChange change);
    
    shared formal void gotoLocation(TypecheckerUnit unit, Integer offset, Integer length);
    
    shared void exportModuleImports(IProject project, Module target, String moduleName) {
        value unit = getUnit(project, target);
        exportModuleImports2(unit[0], unit[1], moduleName);
    }

    shared void removeModuleImports(IProject project, Module target, List<String> moduleNames) {
        if (moduleNames.empty) {
            return;
        }
        
        value unit = getUnit(project, target);
        removeModuleImports2(unit[0], unit[1], moduleNames);
    }

    shared void exportModuleImports2(IFile file, Tree.CompilationUnit cu, String moduleName) {
        value change = newTextChange("Export Module Imports", file);
        initMultiEditChange(change);

        value edit = createExportEdit(cu, moduleName);
        if (exists edit) {
            addEditToChange(change, edit);
        }
        
        performChange(change);
    }
    
    shared void removeModuleImports2(IFile file, Tree.CompilationUnit cu, List<String> moduleNames) {
        value change = newTextChange("Remove Module Imports", file);
        initMultiEditChange(change);

        for (moduleName in moduleNames) {
            value edit = createRemoveEdit(cu, moduleName);
            if (exists edit) {
                addEditToChange(change, edit);
            }
        }
        
        performChange(change);
    }

    shared void addModuleImport(IProject project, Module target, 
        String moduleName, String moduleVersion) {
        
        value versionNode = ModuleVersionNode(ModuleNode(moduleName, 
            Collections.emptyList<ModuleVersionNode>()), moduleVersion);
        
        value offset = addModuleImports2(project, target, 
            map({moduleName -> versionNode}));
        value unit = getUnit(project, target);
        
        gotoLocation(unit[2], offset + moduleName.size + indents.defaultIndent.size + 10, moduleVersion.size);
    }

    shared void makeModuleImportShared(IProject project, Module target,
        ObjectArray<JString> moduleNames) {
        
        value unit = getUnit(project, target);
        value textFileChange = newTextChange("Make Module Import Shared", unit[0]);
        initMultiEditChange(textFileChange);

        value compilationUnit = unit[1];
        value doc = getDocumentForChange(textFileChange);
        
        for (moduleName in moduleNames.iterable) {
            value moduleDescriptor = compilationUnit.moduleDescriptors.get(0);            
            value importModules = moduleDescriptor.importModuleList.importModules;
            
            for (im in CeylonIterable(importModules)) {
                value importedName = nodes.getImportedName(im);
                if (exists importedName, exists moduleName,
                    javaString(importedName).equals(moduleName)) {
                    
                    if (!removeSharedAnnotation(textFileChange, doc, im.annotationList)) {
                        addEditToChange(textFileChange, 
                            newInsertEdit(im.startIndex.intValue(), "shared "));
                    }
                }
            }
        }
        
        performChange(textFileChange);
    }

    shared Boolean removeSharedAnnotation(TextChange textFileChange,
        IDocument doc, Tree.AnnotationList al) {
        
        variable value result = false;
        for (a in CeylonIterable(al.annotations)) {
            assert (is Tree.BaseMemberExpression bme = a.primary);
            if (bme.declaration.name.equals("shared")) {
                variable value stop = a.endIndex.intValue();
                value start = a.startIndex.intValue();

                while (getChar(doc, stop).whitespace) {
                    stop++;
                }
                
                addEditToChange(textFileChange, newDeleteEdit(start, stop - start));
                result = true;
            }
        }
        
        return result;
    }
    
    shared Integer addModuleImports2(IProject project, Module target,
        Map<String,ModuleVersionNode> moduleNamesAndVersions) {
        
        if (moduleNamesAndVersions.empty) {
            return 0;
        }
        
        value unit = getUnit(project, target);
        return addModuleImports3(unit[0], unit[1], project, moduleNamesAndVersions);
    }

    shared Integer addModuleImports3(IFile file, Tree.CompilationUnit cu,
        IProject project, Map<String,ModuleVersionNode> moduleNamesAndVersions) {
        
        value textFileChange = newTextChange("Add Module Imports", file);
        initMultiEditChange(textFileChange);
        
        for (name -> val in moduleNamesAndVersions) {
            value version = val.version;
            value mod = cu.unit.\ipackage.\imodule;

            value nativeBackend = 
            if (exists moduleBackends = mod.nativeBackends,
                exists otherBackend = val.nativeBackend,
                moduleBackends == otherBackend)
            
                then null
                else val.nativeBackend;
            
            value edit = createAddEdit(cu, nativeBackend, name,
                version, getDocumentForChange(textFileChange));
            
            if (exists edit) {
                addEditToChange(textFileChange, edit);
            }
        }
        
        performChange(textFileChange);
        return getEditOffset(textFileChange);
    }


    InsertEdit? createAddEdit(Tree.CompilationUnit unit, Backends? backend, String moduleName, String moduleVersion, IDocument doc) {
        value iml = getImportList(unit);
        if (!exists iml) {
            return null;
        }
        
        Integer offset = (iml.importModules.empty)
            then iml.startIndex.intValue() + 1
            else iml.importModules.get(iml.importModules.size() - 1).endIndex.intValue();
        
        value newline = indents.getDefaultLineDelimiter(doc);
        value importModule = StringBuilder();
        appendImportStatement(importModule, false, backend, moduleName, moduleVersion, newline);
        if (iml.endToken.line == iml.token.line) {
            importModule.append(newline);
        }
        
        return newInsertEdit(offset, importModule.string);
    }

    shared void appendImportStatement(StringBuilder importModule, 
        Boolean shared, Backends? backend, String moduleName,
         String moduleVersion, String newline) {
        
        importModule.append(newline)
                .append(indents.defaultIndent);
        
        if (shared) {
            importModule.append("shared ");
        }
        
        if (exists backend) {
            appendNative(importModule, backend);
            importModule.append(" ");
        }
        
        importModule.append("import ");
        if (!javaString(moduleName).matches("^[a-z_]\\w*(\\.[a-z_]\\w*)*$")) {
            importModule.append("\"")
                    .append(moduleName)
                    .append("\"");
        } else {
            importModule.append(moduleName);
        }
        
        importModule.append(" \"")
                .append(moduleVersion)
                .append("\";");
    }

    shared void appendNative(StringBuilder builder, Backends backends) {
        builder.append("native(");
        appendNativeBackends(builder, backends);
        builder.append(")");
    }
    
    shared void appendNativeBackends(StringBuilder builder, Backends backends) {
        value it = CeylonIterable(backends);
        builder.append(", ".join(it.map((be) => "\"``be.nativeAnnotation``\"")));
    }

    
    TextEdit? createRemoveEdit(Tree.CompilationUnit unit, String moduleName) {
        value iml = getImportList(unit);
        if (!exists iml) {
            return null;
        }
        
        variable Tree.ImportModule? prev = null;
        
        for (im in CeylonIterable(iml.importModules)) {
            value ip = nodes.getImportedName(im);
            if (exists ip, ip.equals(moduleName)) {
                variable value startOffset = im.startIndex.intValue();
                variable value length = im.distance.intValue();
                if (exists p = prev) {
                    value endOffset = p.endIndex.intValue();
                    length += startOffset-endOffset;
                    startOffset = endOffset;
                }
                
                return newDeleteEdit(startOffset, length);
            }
            
            prev = im;
        }
        
        return null;
    }

    InsertEdit? createExportEdit(Tree.CompilationUnit unit, String moduleName) {
        value iml = getImportList(unit);
        if (!exists iml) {
            return null;
        }
        
        for (im in CeylonIterable(iml.importModules)) {
            value ip = nodes.getImportedName(im);
            if (exists ip, ip.equals(moduleName)) {
                value startOffset = im.startIndex;
                return newInsertEdit(startOffset.intValue(), "shared ");
            }
        }
        
        return null;
    }

    Tree.ImportModuleList? getImportList(Tree.CompilationUnit unit) {
        value moduleDescriptors = unit.moduleDescriptors;
        if (!moduleDescriptors.empty) {
            value moduleDescriptor = moduleDescriptors.get(0);
            return moduleDescriptor.importModuleList;
        } else {
            return null;
        }
    }

}
