import com.redhat.ceylon.model.loader.model {
    LazyModuleManager
}
import com.redhat.ceylon.compiler.java.loader.model {
    LazyModuleSourceMapper
}
import com.redhat.ceylon.compiler.typechecker.context {
    Context
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared abstract class IdeModuleManager() extends LazyModuleManager() {
    shared formal void addTopLevelModuleError();
    shared actual formal IdeModelLoader modelLoader;
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared abstract class IdeModuleSourceMapper(Context context, LazyModuleManager moduleManager) extends LazyModuleSourceMapper(context, moduleManager) {
}