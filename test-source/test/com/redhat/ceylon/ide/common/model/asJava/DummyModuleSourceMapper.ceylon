import com.redhat.ceylon.compiler.typechecker.context {
    Context
}
import java.io {
    File
}
import com.redhat.ceylon.ide.common.model {
    IdeModuleSourceMapper,
    IdeModuleManager,
    BaseIdeModule
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}

shared class DummyModuleSourceMapper(
    Context context, 
    IdeModuleManager<DummyProject, File, File, File> theModuleManager) 
        extends IdeModuleSourceMapper<DummyProject, File, File, File>(context, theModuleManager){
    
    shared variable Package? currentPackage_ = null;
    currentPackage => currentPackage_;

    shared actual String defaultCharset => "utf8";
    shared actual void logModuleResolvingError(BaseIdeModule theModule, Exception e) {
        e.printStackTrace();
    }
}