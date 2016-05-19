import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Unit
}

import java.lang {
    StringBuilder
}

shared interface PlatformServices {
    shared void register() => _platformServices = this;
    
    shared formal IdeUtils utils();
    shared formal ModelServices<NativeProject, NativeResource, NativeFolder, NativeFile> 
            model<NativeProject, NativeResource, NativeFolder, NativeFile>();
    shared formal VfsServices<NativeProject, NativeResource, NativeFolder, NativeFile> 
            vfs<NativeProject, NativeResource, NativeFolder, NativeFile>();

    shared formal TextChange createTextChange(String name, CommonDocument|PhasedUnit input);
    shared formal CompositeChange createCompositeChange(String name);
    shared formal void gotoLocation(Unit unit, Integer offset, Integer length);

    shared formal Integer indentSpaces;
    shared formal Boolean indentWithSpaces;
    shared String defaultIndent {
        StringBuilder result = StringBuilder();
        initialIndent(result);
        return result.string;
    }
    shared void initialIndent(StringBuilder buf) {
        //guess an initial indent level
        if (indentWithSpaces) {
            value spaces = indentSpaces;
            for (i in 1..spaces) {
                buf.append(' ');
            }
        }
        else {
            buf.append('\t');
        }
    }
    
    shared formal LinkedMode createLinkedMode(CommonDocument document);
}

suppressWarnings("expressionTypeNothing")
variable PlatformServices _platformServices 
        = object satisfies PlatformServices {
    shared actual ModelServices<NativeProject,NativeResource,NativeFolder,NativeFile> 
            model<NativeProject, NativeResource, NativeFolder, NativeFile>() 
            => nothing;
    shared actual IdeUtils utils() => DefaultIdeUtils();
    shared actual VfsServices<NativeProject,NativeResource,NativeFolder,NativeFile> 
            vfs<NativeProject, NativeResource, NativeFolder, NativeFile>() 
            => nothing;
    shared actual TextChange createTextChange(String desc, CommonDocument|PhasedUnit input) 
            => nothing;
    createCompositeChange(String desc) 
            => nothing;
    indentSpaces => 4;
    indentWithSpaces => true;
    gotoLocation(Unit unit, Integer offset, Integer length) => noop();
    createLinkedMode(CommonDocument document) => NoopLinkedMode(document);
};

shared PlatformServices platformServices => _platformServices;
shared IdeUtils platformUtils => platformServices.utils();
