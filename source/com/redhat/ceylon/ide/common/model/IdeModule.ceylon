import com.redhat.ceylon.model.typechecker.model {
    Module
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared abstract class IdeModule() extends Module() {
    shared variable Boolean projectModule = nothing;
    shared {IdeModule*} moduleInReferencingProjects => nothing;
    shared void addedOriginalUnit(String pathRelativeToSrcDir) {}
    shared void removedOriginalUnit(String pathRelativeToSrcDir) {}
}