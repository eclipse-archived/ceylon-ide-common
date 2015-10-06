import com.redhat.ceylon.model.loader {
    AbstractModelLoader
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared abstract class IdeModelLoader() extends AbstractModelLoader() {
    shared formal void addJDKModuleToClassPath(Module jdkModule);
}