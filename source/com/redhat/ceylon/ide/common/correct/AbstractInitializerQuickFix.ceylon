import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport
}
interface AbstractInitializerQuickFix<LinkedMode, Document, CompletionResult,Region>
        satisfies LinkedModeSupport<LinkedMode, Document, CompletionResult> {
    
    shared void addInitializer(Document doc) {
        value linkedMode = newLinkedMode();
        
    }
}